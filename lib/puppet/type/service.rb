# This is our main way of managing processes right now.
#
# a service is distinct from a process in that services
# can only be managed through the interface of an init script
# which is why they have a search path for initscripts and such

module Puppet

    newtype(:service) do
        @doc = "Manage running services.  Service support unfortunately varies
            widely by platform -- some platforms have very little if any
            concept of a running service, and some have a very codified and
            powerful concept.  Puppet's service support will generally be able
            to make up for any inherent shortcomings (e.g., if there is no
            'status' command, then Puppet will look in the process table for a
            command matching the service name), but the more information you
            can provide the better behaviour you will get.  Or, you can just
            use a platform that has very good service support.

            Note that if a ``service`` receives an event from another resource,
            the service will get restarted. The actual command to restart the
            service depends on the platform. You can provide a special command
            for restarting with the ``restart`` attribute."

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

            def retrieve
                return provider.enabled?
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
                return provider.status
            end

            def sync
                event = super()

                if property = @resource.property(:enable)
                    val = property.retrieve
                    property.sync unless property.insync?(val)
                end

                return event
            end
        end

        newparam(:binary) do
            desc "The path to the daemon.  This is only used for
                systems that do not support init scripts.  This binary will be
                used to start the service if no ``start`` parameter is
                provided."
        end

        newparam(:hasstatus) do
            desc "Declare the the service's init script has a
                functional status command.  Based on testing, it was found
                that a large number of init scripts on different platforms do
                not support any kind of status command; thus, you must specify
                manually whether the service you are running has such a
                command (or you can specify a specific command using the
                ``status`` parameter).

                If you do not specify anything, then the service name will be
                looked for in the process table."

            newvalues(:true, :false)
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
                paths = value.flatten.collect { |p| x = p.split(":") }.flatten
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
                support a ``start`` command, so this will not need to be
                specified."
        end
        newparam(:status) do
            desc "Specify a *status* command manually.  If left
                unspecified, the status method will be determined
                automatically, usually by looking for the service in the
                process table."
        end

        newparam(:stop) do
            desc "Specify a *stop* command manually."
        end

        newparam(:control) do
            desc "The control variable used to manage services (originally for HP-UX).
                Defaults to the upcased service name plus ``START`` replacing dots with
                underscores, for those providers that support the ``controllable`` feature."
            defaultto { resource.name.gsub(".","_").upcase + "_START" if resource.provider.controllable? }
        end

        newparam :hasrestart do
            desc "Specify that an init script has a ``restart`` option.  Otherwise,
                the init script's ``stop`` and ``start`` methods are used."
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
