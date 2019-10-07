require 'timeout'

# Solaris 10 SMF-style services.
Puppet::Type.type(:service).provide :smf, :parent => :base do
  desc <<-EOT
    Support for Sun's new Service Management Framework.

    Starting a service is effectively equivalent to enabling it, so there is
    only support for starting and stopping services, which also enables and
    disables them, respectively.

    By specifying `manifest => "/path/to/service.xml"`, the SMF manifest will
    be imported if it does not exist.

  EOT

  defaultfor :osfamily => :solaris

  confine :osfamily => :solaris

  commands :adm => "/usr/sbin/svcadm", :svcs => "/usr/bin/svcs"
  commands :svccfg => "/usr/sbin/svccfg"

  has_feature :refreshable

  def setupservice
      if resource[:manifest]
        begin
          svcs("-l", @resource[:name])
        rescue Puppet::ExecutionFailure
          Puppet.notice "Importing #{@resource[:manifest]} for #{@resource[:name]}"
          svccfg :import, resource[:manifest]
        end
      end
  rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error.new( "Cannot config #{self.name} to enable it: #{detail}", detail )
  end

  def self.instances
   svcs("-H", "-o", "state,fmri" ).split("\n").select{|l| l !~ /^legacy_run/ }.collect do |line|
     state,fmri = line.split(/\s+/)
     status =  case state
               when /online/; :running
               when /maintenance/; :maintenance
               when /degraded/; :degraded
               else :stopped
               end
     new({:name => fmri, :ensure => status})
   end
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
    Puppet::Util::Package.versioncmp(Facter.value(:operatingsystemrelease), '11.1') >= 0
  end

  # Returns true if the service is complete. A complete service is a service that
  # has the general/complete property defined.
  def complete_service?
    unless supports_incomplete_services?
      raise Puppet::Error, _("Cannot query if the %{service} service is complete: The concept of complete/incomplete services was introduced in Solaris 11.1. You are on a Solaris %{release} machine.") % { service: @resource[:name], release: Facter.value(:operatingsystemrelease) }
    end

    return @complete_service if @complete_service

    # We need to use the service's FMRI when querying its config. because
    # general/complete is an instance-specific property.
    fmri = service_fmri

    # Check if the general/complete property is defined. If it is undefined,
    # then svccfg will not print anything to the console.
    property_defn = svccfg("-s", fmri, "listprop", "general/complete").chomp
    @complete_service = ! property_defn.empty?
  end

  def enable
    self.start
  end

  def enabled?
    case self.status
    when :running
      return :true
    else
      return :false
    end
  end

  def disable
    self.stop
  end

  def restartcmd
    if Puppet::Util::Package.versioncmp(Facter.value(:operatingsystemrelease), '11.2') >= 0
      [command(:adm), :restart, "-s", @resource[:name]]
    else
      # Synchronous restart only supported in Solaris 11.2 and above
      [command(:adm), :restart, @resource[:name]]
    end
  end

  def startcmd
    self.setupservice
    case self.status
    when :maintenance, :degraded
      [command(:adm), :clear, @resource[:name]]
    else
      [command(:adm), :enable, "-rs", @resource[:name]]
    end
  end

  # Wait for the service to transition into the specified state before returning.
  # This is necessary due to the asynchronous nature of SMF services.
  # desired_state should be online, offline, disabled, or uninitialized.
  # See PUP-5474 for long-term solution to this issue.
  def wait(*desired_state)
    Timeout.timeout(60) do
      loop do
        states = self.service_states
        break if desired_state.include?(states[0]) && states[1] == '-'
        sleep(1)
      end
    end
  rescue Timeout::Error
    raise Puppet::Error.new("Timed out waiting for #{@resource[:name]} to transition states")
  end

  def start
    # Wait for the service to actually start before returning.
    super
    self.wait('online')
  end

  def stop
    # Wait for the service to actually stop before returning.
    super
    self.wait('offline', 'disabled', 'uninitialized')
  end

  def restart
    # Wait for the service to actually start before returning.
    super
    self.wait('online')
  end

  # Determine the current and next states of a service.
  def service_states
    svcs("-H", "-o", "state,nstate", @resource[:name]).chomp.split
  end

  def status
    if @resource[:status]
      super
      return
    end

    begin
      if supports_incomplete_services?
        unless complete_service?
          debug _("The %{service} service is incomplete so its status will be reported as :stopped. See `svcs -xv %{fmri}` for more details.") % { service: @resource[:name], fmri: service_fmri }

          return :stopped
        end
      end

      # get the current state and the next state, and if the next
      # state is set (i.e. not "-") use it for state comparison
      states = service_states
      state = states[1] == "-" ? states[0] : states[1]
    rescue Puppet::ExecutionFailure
      # TODO (PUP-8957): Should this be set back to INFO ?
      debug "Could not get status on service #{self.name} #{$!}"
      return :stopped
    end

    case state
    when "online"
      #self.warning "matched running #{line.inspect}"
      return :running
    when "offline", "disabled", "uninitialized"
      #self.warning "matched stopped #{line.inspect}"
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

  def stopcmd
    [command(:adm), :disable, "-s", @resource[:name]]
  end
end

