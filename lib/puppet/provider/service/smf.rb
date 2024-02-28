# frozen_string_literal: true

require 'timeout'

# Solaris 10 SMF-style services.
Puppet::Type.type(:service).provide :smf, :parent => :base do
  desc <<-EOT
    Support for Sun's new Service Management Framework.

    When managing the enable property, this provider will try to preserve
    the previous ensure state per the enableable semantics. On Solaris,
    enabling a service starts it up while disabling a service stops it. Thus,
    there's a chance for this provider to execute two operations when managing
    the enable property. For example, if enable is set to true and the ensure
    state is stopped, this provider will manage the service using two operations:
    one to enable the service which will start it up, and another to stop the
    service (without affecting its enabled status).

    By specifying `manifest => "/path/to/service.xml"`, the SMF manifest will
    be imported if it does not exist.
  EOT

  defaultfor 'os.family' => :solaris

  confine 'os.family' => :solaris

  commands :adm => "/usr/sbin/svcadm",
           :svcs => "/usr/bin/svcs",
           :svccfg => "/usr/sbin/svccfg"

  has_feature :refreshable

  def self.instances
    service_instances = svcs("-H", "-o", "state,fmri").split("\n")

    # Puppet does not manage services in the legacy_run state, so filter those out.
    service_instances.reject! { |line| line =~ /^legacy_run/ }

    service_instances.collect! do |line|
      state, fmri = line.split(/\s+/)

      status =  case state
                when /online/; :running
                when /maintenance/; :maintenance
                when /degraded/; :degraded
                else :stopped
                end
      new({ :name => fmri, :ensure => status })
    end

    service_instances
  end

  def initialize(*args)
    super(*args)

    # This hash contains the properties we need to sync. in our flush method.
    #
    # TODO (PUP-9051): Should we use @property_hash here? It seems like
    # @property_hash should be empty by default and is something we can
    # control so I think so?
    @properties_to_sync = {}
  end

  def service_exists?
    self.service_fmri
    true
  rescue Puppet::ExecutionFailure
    false
  end

  def setup_service
    return unless @resource[:manifest]
    return if self.service_exists?

    Puppet.notice("Importing #{@resource[:manifest]} for #{@resource[:name]}")
    svccfg(:import, @resource[:manifest])
  rescue Puppet::ExecutionFailure => detail
    raise Puppet::Error.new("Cannot config #{@resource[:name]} to enable it: #{detail}", detail)
  end

  # Returns the service's FMRI. We fail if multiple FMRIs correspond to
  # @resource[:name].
  #
  # If the service does not exist or we fail to get any FMRIs from svcs,
  # this method will raise a Puppet::Error
  def service_fmri
    return @fmri if @fmri

    # `svcs -l` is better to use because we can detect service instances
    # that have not yet been activated or enabled (i.e. it lets us detect
    # services that svcadm has not yet touched). `svcs -H -o fmri` is a bit
    # more limited.
    lines = svcs("-l", @resource[:name]).chomp.lines.to_a
    lines.select! { |line| line =~ /^fmri/ }
    fmris = lines.map! { |line| line.split(' ')[-1].chomp }
    unless fmris.length == 1
      raise Puppet::Error, _("Failed to get the FMRI of the %{service} service: The pattern '%{service}' matches multiple FMRIs! These are the FMRIs it matches: %{all_fmris}") % { service: @resource[:name], all_fmris: fmris.join(', ') }
    end

    @fmri = fmris.first
  end

  # Returns true if the provider supports incomplete services.
  def supports_incomplete_services?
    Puppet::Util::Package.versioncmp(Puppet.runtime[:facter].value('os.release.full'), '11.1') >= 0
  end

  # Returns true if the service is complete. A complete service is a service that
  # has the general/complete property defined.
  def complete_service?
    unless supports_incomplete_services?
      raise Puppet::Error, _("Cannot query if the %{service} service is complete: The concept of complete/incomplete services was introduced in Solaris 11.1. You are on a Solaris %{release} machine.") % { service: @resource[:name], release: Puppet.runtime[:facter].value('os.release.full') }
    end

    return @complete_service if @complete_service

    # We need to use the service's FMRI when querying its config. because
    # general/complete is an instance-specific property.
    fmri = service_fmri

    # Check if the general/complete property is defined. If it is undefined,
    # then svccfg will not print anything to the console.
    property_defn = svccfg("-s", fmri, "listprop", "general/complete").chomp
    @complete_service = !property_defn.empty?
  end

  def enable
    @properties_to_sync[:enable] = true
  end

  def enabled?
    return :false unless service_exists?

    _property, _type, value = svccfg("-s", self.service_fmri, "listprop", "general/enabled").split(' ')
    value == 'true' ? :true : :false
  end

  def disable
    @properties_to_sync[:enable] = false
  end

  def restartcmd
    if Puppet::Util::Package.versioncmp(Puppet.runtime[:facter].value('os.release.full'), '11.2') >= 0
      [command(:adm), :restart, "-s", self.service_fmri]
    else
      # Synchronous restart only supported in Solaris 11.2 and above
      [command(:adm), :restart, self.service_fmri]
    end
  end

  def service_states
    # Gets the current and next state of the service. We have a next state because SMF
    # manages services asynchronously. If there is no 'next' state, svcs will put a '-'
    # to indicate as such.
    current_state, next_state = svcs("-H", "-o", "state,nstate", self.service_fmri).chomp.split(' ')

    {
      :current => current_state,
      :next => next_state == "-" ? nil : next_state
    }
  end

  # Wait for the service to transition into the specified state before returning.
  # This is necessary due to the asynchronous nature of SMF services.
  # desired_states should include only online, offline, disabled, or uninitialized.
  # See PUP-5474 for long-term solution to this issue.
  def wait(*desired_states)
    Timeout.timeout(60) do
      loop do
        states = self.service_states
        break if desired_states.include?(states[:current]) && states[:next].nil?

        Kernel.sleep(1)
      end
    end
  rescue Timeout::Error
    raise Puppet::Error, "Timed out waiting for #{@resource[:name]} to transition states"
  end

  def start
    @properties_to_sync[:ensure] = :running
  end

  def stop
    @properties_to_sync[:ensure] = :stopped
  end

  def restart
    # Wait for the service to actually start before returning.
    super
    self.wait('online')
  end

  def status
    return super if @resource[:status]

    begin
      if supports_incomplete_services?
        unless complete_service?
          debug _("The %{service} service is incomplete so its status will be reported as :stopped. See `svcs -xv %{fmri}` for more details.") % { service: @resource[:name], fmri: service_fmri }

          return :stopped
        end
      end

      # Get the current state and the next state. If there is a next state,
      # use that for the state comparison.
      states = self.service_states
      state = states[:next] || states[:current]
    rescue Puppet::ExecutionFailure
      # TODO (PUP-8957): Should this be set back to INFO ?
      debug "Could not get status on service #{self.name} #{$!}"
      return :stopped
    end

    case state
    when "online"
      return :running
    when "offline", "disabled", "uninitialized"
      return :stopped
    when "maintenance"
      return :maintenance
    when "degraded"
      return :degraded
    when "legacy_run"
      raise Puppet::Error,
            "Cannot manage legacy services through SMF"
    else
      raise Puppet::Error,
            "Unmanageable state '#{state}' on service #{self.name}"
    end
  end

  # Helper that encapsulates the clear + svcadm [enable|disable]
  # logic in one place. Makes it easy to test things out and also
  # cleans up flush's code.
  def maybe_clear_service_then_svcadm(cur_state, subcmd, flags)
    # If the cur_state is maint or degraded, then we need to clear the service
    # before we enable or disable it.
    adm('clear', self.service_fmri) if [:maintenance, :degraded].include?(cur_state)
    adm(subcmd, flags, self.service_fmri)
  end

  # The flush method is necessary for the SMF provider because syncing the enable and ensure
  # properties are not independent operations like they are in most of our other service
  # providers.
  def flush
    # We append the "_" because ensure is a Ruby keyword, and it is good to keep property
    # variable names consistent with each other.
    enable_ = @properties_to_sync[:enable]
    ensure_ = @properties_to_sync[:ensure]

    # All of the relevant properties are in sync., so we do not need to do
    # anything here.
    return if enable_.nil? and ensure_.nil?

    # Set-up our service so that we know it will exist and so we can collect its fmri. Also
    # simplifies the code. For a nonexistent service, one of enable or ensure will be true
    # here (since we're syncing them), so we can fail early if setup_service fails.
    setup_service
    fmri = self.service_fmri

    # Useful constants for operations involving multiple states
    stopped = ['offline', 'disabled', 'uninitialized']

    # Get the current state of the service.
    cur_state = self.status

    if enable_.nil?
      # Only ensure needs to be syncd. The -t flag tells svcadm to temporarily
      # enable/disable the service, where the temporary status is gone upon
      # reboot. This is exactly what we want, because we do not want to touch
      # the enable property.
      if ensure_ == :stopped
        self.maybe_clear_service_then_svcadm(cur_state, 'disable', '-st')
        wait(*stopped)
      else # ensure == :running
        self.maybe_clear_service_then_svcadm(cur_state, 'enable', '-rst')
        wait('online')
      end

      return
    end

    # Here, enable is being syncd. svcadm starts the service if we enable it, or shuts it down if we
    # disable it. However, we want our service to be in a final state, which is either whatever the
    # new ensured value is, or what our original state was prior to enabling it.
    #
    # NOTE: Even if you try to set the general/enabled property with svccfg, SMF will still
    # try to start or shut down the service. Plus, setting general/enabled with svccfg does not
    # enable the service's dependencies, while svcadm handles this correctly.
    #
    # NOTE: We're treating :running and :degraded the same. The reason is b/c an SMF managed service
    # can only enter the :degraded state if it is online. Since disabling the service also shuts it
    # off, we cannot set it back to the :degraded state. Thus, it is best to lump :running and :degraded
    # into the same category to maintain a consistent postcondition on the service's final state when
    # enabling and disabling it.
    final_state = ensure_ || cur_state
    final_state = :running if final_state == :degraded

    if enable_
      self.maybe_clear_service_then_svcadm(cur_state, 'enable', '-rs')
    else
      self.maybe_clear_service_then_svcadm(cur_state, 'disable', '-s')
    end

    # We're safe with 'whens' here since self.status already errors on any
    # unmanageable states.
    case final_state
    when :running
      adm('enable', '-rst', fmri) unless enable_
      wait('online')
    when :stopped
      adm('disable', '-st', fmri) if enable_
      wait(*stopped)
    when :maintenance
      adm('mark', '-I', 'maintenance', fmri)
      wait('maintenance')
    end
  end
end
