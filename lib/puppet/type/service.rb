# This is our main way of managing processes right now.
#
# a service is distinct from a process in that services
# can only be managed through the interface of an init script
# which is why they have a search path for initscripts and such

module Puppet

  newtype(:service) do
    @doc = "Manage running services.  Service support unfortunately varies
      widely by platform --- some platforms have very little if any concept of a
      running service, and some have a very codified and powerful concept.
      Puppet's service support is usually capable of doing the right thing, but
      the more information you can provide, the better behaviour you will get.

      Puppet 2.7 and newer expect init scripts to have a working status command.
      If this isn't the case for any of your services' init scripts, you will
      need to set `hasstatus` to false and possibly specify a custom status
      command in the `status` attribute.

      Note that if a `service` receives an event from another resource,
      the service will get restarted. The actual command to restart the
      service depends on the platform. You can provide an explicit command
      for restarting with the `restart` attribute, or use the init script's
      restart command with the `hasrestart` attribute; if you do neither,
      the service's stop and start commands will be used."

    feature :refreshable, "The provider can restart the service.",
      :methods => [:restart]

    feature :enableable, "The provider can enable and disable the service",
      :methods => [:disable, :enable, :enabled?]

    feature :controllable, "The provider uses a control variable."

    newproperty(:enable, :required_features => :enableable) do
      desc "Whether a service should be enabled to start at boot.
        This property behaves quite differently depending on the platform;
        wherever possible, it relies on local tools to enable or disable
        a given service."

      newvalue(:true, :event => :service_enabled) do
        provider.enable
      end

      newvalue(:false, :event => :service_disabled) do
        provider.disable
      end

      newvalue(:manual, :event => :service_manual_start) do
        provider.manual_start
      end

      def retrieve
        provider.enabled?
      end

      validate do |value|
        if value == :manual and !Puppet.features.microsoft_windows?
          raise Puppet::Error.new("Setting enable to manual is only supported on Microsoft Windows.")
        end
      end
    end

    # Handle whether the service should actually be running right now.
    newproperty(:ensure) do
      desc "Whether a service should be running."

      newvalue(:stopped, :event => :service_stopped) do
        provider.stop
      end

      newvalue(:running, :event => :service_started) do
        provider.start
      end

      aliasvalue(:false, :stopped)
      aliasvalue(:true, :running)

      def retrieve
        provider.status
      end

      def sync
        event = super()

        if property = @resource.property(:enable)
          val = property.retrieve
          property.sync unless property.safe_insync?(val)
        end

        event
      end
    end

    newparam(:binary) do
      desc "The path to the daemon.  This is only used for
        systems that do not support init scripts.  This binary will be
        used to start the service if no `start` parameter is
        provided."
    end

    newparam(:hasstatus) do
      desc "Declare whether the service's init script has a functional status
        command; defaults to `true`. This attribute's default value changed in
        Puppet 2.7.0.

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
      desc "The name of the service to run.  This name is used to find
        the service in whatever service subsystem it is in."
      isnamevar
    end

    newparam(:path) do
      desc "The search path for finding init scripts.  Multiple values should
        be separated by colons or provided as an array."

      munge do |value|
        value = [value] unless value.is_a?(Array)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
        # It affects stand-alone blocks, too.
        paths = value.flatten.collect { |p| x = p.split(File::PATH_SEPARATOR) }.flatten
      end

      defaultto { provider.class.defpath if provider.class.respond_to?(:defpath) }
    end
    newparam(:pattern) do
      desc "The pattern to search for in the process table.
        This is used for stopping services on platforms that do not
        support init scripts, and is also used for determining service
        status on those service whose init scripts do not include a status
        command.

        If this is left unspecified and is needed to check the status
        of a service, then the service name will be used instead.

        The pattern can be a simple string or any legal Ruby pattern."

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
        Ideally, these return codes should conform to
        [the LSB's specification for init script status actions](http://refspecs.freestandards.org/LSB_3.1.1/LSB-Core-generic/LSB-Core-generic/iniscrptact.html),
        but puppet only considers the difference between 0 and nonzero
        to be relevant.

        If left unspecified, the status method will be determined
        automatically, usually by looking for the service in the process
        table."
    end

    newparam(:stop) do
      desc "Specify a *stop* command manually."
    end

    newparam(:control) do
      desc "The control variable used to manage services (originally for HP-UX).
        Defaults to the upcased service name plus `START` replacing dots with
        underscores, for those providers that support the `controllable` feature."
      defaultto { resource.name.gsub(".","_").upcase + "_START" if resource.provider.controllable? }
    end

    newparam :hasrestart do
      desc "Specify that an init script has a `restart` option.  Otherwise,
        the init script's `stop` and `start` methods are used."
      newvalues(:true, :false)
    end

    newparam(:manifest) do
      desc "Specify a command to config a service, or a path to a manifest to do so."
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
  end
end
