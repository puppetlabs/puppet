# frozen_string_literal: true

# This is our main way of managing processes right now.
#
# a service is distinct from a process in that services
# can only be managed through the interface of an init script
# which is why they have a search path for initscripts and such

module Puppet
  Type.newtype(:service) do
    @doc = "Manage running services.  Service support unfortunately varies
      widely by platform --- some platforms have very little if any concept of a
      running service, and some have a very codified and powerful concept.
      Puppet's service support is usually capable of doing the right thing, but
      the more information you can provide, the better behaviour you will get.

      Puppet 2.7 and newer expect init scripts to have a working status command.
      If this isn't the case for any of your services' init scripts, you will
      need to set `hasstatus` to false and possibly specify a custom status
      command in the `status` attribute. As a last resort, Puppet will attempt to
      search the process table by calling whatever command is listed in the `ps`
      fact. The default search pattern is the name of the service, but you can
      specify it with the `pattern` attribute.

      **Refresh:** `service` resources can respond to refresh events (via
      `notify`, `subscribe`, or the `~>` arrow). If a `service` receives an
      event from another resource, Puppet will restart the service it manages.
      The actual command used to restart the service depends on the platform and
      can be configured:

      * If you set `hasrestart` to true, Puppet will use the init script's restart command.
      * You can provide an explicit command for restarting with the `restart` attribute.
      * If you do neither, the service's stop and start commands will be used."

    feature :refreshable, "The provider can restart the service.",
            :methods => [:restart]

    feature :enableable, "The provider can enable and disable the service.",
            :methods => [:disable, :enable, :enabled?]

    feature :delayed_startable, "The provider can set service to delayed start",
            :methods => [:delayed_start]

    feature :manual_startable, "The provider can set service to manual start",
            :methods => [:manual_start]

    feature :controllable, "The provider uses a control variable."

    feature :flaggable, "The provider can pass flags to the service."

    feature :maskable, "The provider can 'mask' the service.",
            :methods => [:mask]

    feature :configurable_timeout, "The provider can specify a minumum timeout for syncing service properties"

    feature :manages_logon_credentials, "The provider can specify the logon credentials used for a service"

    newproperty(:enable, :required_features => :enableable) do
      desc "Whether a service should be enabled to start at boot.
        This property behaves differently depending on the platform;
        wherever possible, it relies on local tools to enable or disable
        a given service. Default values depend on the platform.

        If you don't specify a value for the `enable` attribute, Puppet leaves
        that aspect of the service alone and your operating system determines
        the behavior."

      newvalue(:true, :event => :service_enabled) do
        provider.enable
      end

      newvalue(:false, :event => :service_disabled) do
        provider.disable
      end

      newvalue(:manual, :event => :service_manual_start, :required_features => :manual_startable) do
        provider.manual_start
      end

      # This only makes sense on systemd systems. Otherwise, it just defaults
      # to disable.
      newvalue(:mask, :event => :service_disabled, :required_features => :maskable) do
        provider.mask
      end

      def retrieve
        provider.enabled?
      end

      newvalue(:delayed, :event => :service_delayed_start, :required_features => :delayed_startable) do
        provider.delayed_start
      end

      def insync?(current)
        return provider.enabled_insync?(current) if provider.respond_to?(:enabled_insync?)

        super(current)
      end
    end

    # Handle whether the service should actually be running right now.
    newproperty(:ensure) do
      desc "Whether a service should be running. Default values depend on the platform."

      newvalue(:stopped, :event => :service_stopped) do
        provider.stop
      end

      newvalue(:running, :event => :service_started, :invalidate_refreshes => true) do
        provider.start
      end

      newvalue(:absent)

      validate do |val|
        fail "Managing absent on a service is not supported" if val.to_s == 'absent'
      end

      aliasvalue(:false, :stopped)
      aliasvalue(:true, :running)

      def retrieve
        provider.status
      end

      def sync
        property = @resource.property(:logonaccount)
        if property
          val = property.retrieve
          property.sync unless property.safe_insync?(val)
        end

        event = super()

        property = @resource.property(:enable)
        if property
          val = property.retrieve
          property.sync unless property.safe_insync?(val)
        end

        event
      end
    end

    newproperty(:logonaccount, :required_features => :manages_logon_credentials) do
      desc "Specify an account for service logon"

      def insync?(current)
        return provider.logonaccount_insync?(current) if provider.respond_to?(:logonaccount_insync?)

        super(current)
      end
    end

    newparam(:logonpassword, :required_features => :manages_logon_credentials) do
      desc "Specify a password for service logon. Default value is an empty string (when logonaccount is specified)."

      validate do |value|
        raise ArgumentError, _("Passwords cannot include ':'") if value.is_a?(String) && value.include?(":")
      end

      sensitive true
      defaultto { @resource[:logonaccount] ? "" : nil }
    end

    newproperty(:flags, :required_features => :flaggable) do
      desc "Specify a string of flags to pass to the startup script."
    end

    newparam(:binary) do
      desc "The path to the daemon.  This is only used for
        systems that do not support init scripts.  This binary will be
        used to start the service if no `start` parameter is
        provided."
    end

    newparam(:hasstatus) do
      desc "Declare whether the service's init script has a functional status
        command. This attribute's default value changed in Puppet 2.7.0.

        The init script's status command must return 0 if the service is
        running and a nonzero value otherwise. Ideally, these exit codes
        should conform to [the LSB's specification][lsb-exit-codes] for init
        script status actions, but Puppet only considers the difference
        between 0 and nonzero to be relevant.

        If a service's init script does not support any kind of status command,
        you should set `hasstatus` to false and either provide a specific
        command using the `status` attribute or expect that Puppet will look for
        the service name in the process table. Be aware that 'virtual' init
        scripts (like 'network' under Red Hat systems) will respond poorly to
        refresh events from other resources if you override the default behavior
        without providing a status command."

      newvalues(:true, :false)

      defaultto :true
    end
    newparam(:name) do
      desc <<-EOT
        The name of the service to run.

        This name is used to find the service; on platforms where services
        have short system names and long display names, this should be the
        short name. (To take an example from Windows, you would use "wuauserv"
        rather than "Automatic Updates.")
      EOT
      isnamevar
    end

    newparam(:path) do
      desc "The search path for finding init scripts.  Multiple values should
        be separated by colons or provided as an array."

      munge do |value|
        value = [value] unless value.is_a?(Array)
        value.flatten.collect { |p| p.split(File::PATH_SEPARATOR) }.flatten
      end

      defaultto { provider.class.defpath if provider.class.respond_to?(:defpath) }
    end
    newparam(:pattern) do
      desc "The pattern to search for in the process table.
        This is used for stopping services on platforms that do not
        support init scripts, and is also used for determining service
        status on those service whose init scripts do not include a status
        command.

        Defaults to the name of the service. The pattern can be a simple string
        or any legal Ruby pattern, including regular expressions (which should
        be quoted without enclosing slashes)."

      defaultto { @resource[:binary] || @resource[:name] }
    end
    newparam(:restart) do
      desc "Specify a *restart* command manually.  If left
        unspecified, the service will be stopped and then started."
    end
    newparam(:start) do
      desc "Specify a *start* command manually.  Most service subsystems
        support a `start` command, so this will not need to be
        specified."
    end
    newparam(:status) do
      desc "Specify a *status* command manually.  This command must
        return 0 if the service is running and a nonzero value otherwise.
        Ideally, these exit codes should conform to [the LSB's
        specification][lsb-exit-codes] for init script status actions, but
        Puppet only considers the difference between 0 and nonzero to be
        relevant.

        If left unspecified, the status of the service will be determined
        automatically, usually by looking for the service in the process
        table.

        [lsb-exit-codes]: http://refspecs.linuxfoundation.org/LSB_4.1.0/LSB-Core-generic/LSB-Core-generic/iniscrptact.html"
    end

    newparam(:stop) do
      desc "Specify a *stop* command manually."
    end

    newparam(:control) do
      desc "The control variable used to manage services (originally for HP-UX).
        Defaults to the upcased service name plus `START` replacing dots with
        underscores, for those providers that support the `controllable` feature."
      defaultto { resource.name.tr(".", "_").upcase + "_START" if resource.provider.controllable? }
    end

    newparam :hasrestart do
      desc "Specify that an init script has a `restart` command.  If this is
        false and you do not specify a command in the `restart` attribute,
        the init script's `stop` and `start` commands will be used."
      newvalues(:true, :false)
    end

    newparam(:manifest) do
      desc "Specify a command to config a service, or a path to a manifest to do so."
    end

    newparam(:timeout, :required_features => :configurable_timeout) do
      desc "Specify an optional minimum timeout (in seconds) for puppet to wait when syncing service properties"
      defaultto { provider.respond_to?(:default_timeout) ? provider.default_timeout : 10 }

      munge do |value|
        begin
          value = value.to_i
          raise if value < 1

          value
        rescue
          raise Puppet::Error.new(_("\"%{value}\" is not a positive integer: the timeout parameter must be specified as a positive integer") % { value: value })
        end
      end
    end

    # Basically just a synonym for restarting.  Used to respond
    # to events.
    def refresh
      # Only restart if we're actually running
      if (@parameters[:ensure] || newattr(:ensure)).retrieve == :running
        provider.restart
      else
        debug "Skipping restart; service is not running"
      end
    end

    def self.needs_ensure_retrieved
      false
    end

    validate do
      if @parameters[:logonpassword] && @parameters[:logonaccount].nil?
        raise Puppet::Error.new(_("The 'logonaccount' parameter is mandatory when setting 'logonpassword'."))
      end
    end
  end
end
