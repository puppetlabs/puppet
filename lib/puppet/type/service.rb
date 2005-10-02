# this is our main way of managing processes right now
#
# a service is distinct from a process in that services
# can only be managed through the interface of an init script
# which is why they have a search path for initscripts and such

module Puppet
    class State
        # Handle whether the service is started at boot time.
        class ServiceEnabled < State
            @doc = "Whether a service should be enabled to start at boot.
                **true**/*false*/*runlevel*"
            @name = :enabled

            def retrieve
                @is = @parent.enabled?
            end

            def shouldprocess(should)
                case should
                when true: return :enabled
                when false: return :disabled
                else
                    raise Puppet::Error, "Invalid 'enabled' value %s" % should
                end
            end

            def sync
                case self.should
                when :enabled
                    unless @parent.respond_to?(:enable)
                        raise Puppet::Error, "Service %s does not support enabling"
                    end
                    @parent.enable
                    return :service_enabled
                when :disabled
                    unless @parent.respond_to?(:disable)
                        raise Puppet::Error,
                            "Service %s does not support disabling"
                    end
                    @parent.disable
                    return :service_disabled
                end
            end
        end

        # Handle whether the service should actually be running right now.
        class ServiceRunning < State
            @doc = "Whether a service should be running.  **true**/*false*"
            @name = :running

            def shouldprocess(should)
                case should
                when false,0,"0", "stopped", :stopped:
                    should = :stopped
                when true,1,"1", :running, "running":
                    should = :running
                else
                    Puppet.warning "%s: interpreting '%s' as false" %
                        [self.class,should]
                    should = 0
                end
                Puppet.debug "Service should is %s" % should
                return should
            end

            def retrieve
                self.is = @parent.status
                Puppet.debug "Running value for '%s' is '%s'" %
                    [self.parent.name,self.is]
            end

            def sync
                event = nil
                case self.should
                when :running
                    @parent.start
                    event = :service_started
                when :stopped
                    @parent.stop
                    event = :service_stopped
                else
                    Puppet.debug "Not running '%s' and shouldn't be running" %
                        self
                end
            end
        end
    end

	class Type
		class Service < Type
			attr_reader :stat
			@states = [
                Puppet::State::ServiceRunning
            ]
			@parameters = [
                :binary,
                :hasstatus,
                :name,
                :path,
                :pattern,
                :restart,
                :start,
                :status,
                :stop
            ]

            @paramdoc[:binary] = "The path to the daemon.  This is only used for
                systems that do not support init scripts."
            @paramdoc[:hasstatus] = "Declare the the service's init script has a
                functional status command.  This is assumed to be default for
                most systems, although there might be platforms on which this is
                assumed to be true."
            @paramdoc[:name] = "The name of the service to run.  This name
                is used to find the init script in the search path."
            @paramdoc[:path] = "The search path for finding init scripts.
                There is currently no default, but hopefully soon there will
                be a reasonable default for all platforms."
            @paramdoc[:pattern] = "The pattern to search for in the process table.
                This is used for stopping services on platforms that do not
                support init scripts, and is also used for determining service
                status on those service whose init scripts do not include a status
                command."
            @paramdoc[:restart] = "Specify a *restart* command manually.  If left
                unspecified, the restart method will be determined automatically."
            @paramdoc[:start] = "Specify a *start* command manually.  If left
                unspecified, the start method will be determined automatically."
            @paramdoc[:status] = "Specify a *status* command manually.  If left
                unspecified, the status method will be determined automatically."
            @paramdoc[:stop] = "Specify a *stop* command manually.  If left
                unspecified, the stop method will be determined automatically."

            @doc = "Manage running services.  Rather than supporting managing
                individual processes, puppet uses init scripts to simplify
                specification of how to start, stop, or test processes.  The
                `path` parameter is provided to enable creation of multiple
                init script directories, including supporting them for normal
                users."
            @name = :service
			@namevar = :name

            # Return the service type we're using.  Default to the Service
            # class itself, but could be set to a module.
            class << self
                attr_accessor :svctype
            end

            # Execute a command.  Basically just makes sure it exits with a 0
            # code.
            def execute(type, cmd)
                output = %x(#{cmd} 2>&1)
                unless $? == 0
                    raise Puppet::Error, "Could not %s %s: %s" %
                        [type, self.name, output.chomp]
                end
            end

            # Get the process ID for a running process. Requires the 'pattern'
            # parameter.
            def getpid
                unless self[:pattern]
                    raise Puppet::Error,
                        "Either a stop command or a pattern must be specified"
                end
                ps = Facter["ps"].value
                regex = Regexp.new(self[:pattern])
                IO.popen(ps) { |table|
                    table.each { |line|
                        if regex.match(line)
                            ary = line.split(/\s+/)
                            return ary[1]
                        end
                    }
                }

                return nil
            end

            def initialize(hash)
                super

                if self.respond_to?(:configchk)
                    self.configchk
                end
            end

            # Basically just a synonym for restarting.  Used to respond
            # to events.
            def refresh
                self.restart
            end

            # How to restart the process.
            def restart
                if self[:restart] or self.respond_to?(:restartcmd)
                    cmd = self[:restart] || self.restartcmd
                    self.execute("restart", cmd)
                else
                    self.stop
                    self.start
                end
            end

            # Check if the process is running.  Prefer the 'status' parameter,
            # then 'statuscmd' method, then look in the process table.  We give
            # the object the option to not return a status command, which might
            # happen if, for instance, it has an init script (and thus responds to
            # 'statuscmd') but does not have 'hasstatus' enabled.
            def status
                if self[:status] or (
                    self.respond_to?(:statuscmd) and self.statuscmd
                )
                    cmd = self[:status] || self.statuscmd
                    output = %x(#{cmd} 2>&1)
                    Puppet.debug "%s status returned %s" %
                        [self.name, output]
                    if $? == 0
                        return :running
                    else
                        return :stopped
                    end
                elsif pid = self.getpid
                    return :running
                else
                    return :stopped
                end
            end

            # Run the 'start' parameter command, or the specified 'startcmd'.
            def start
                cmd = self[:start] || self.startcmd
                self.execute("start", cmd)
            end

            # Stop the service.  If a 'stop' parameter is specified, it
            # takes precedence; otherwise checks if the object responds to
            # a 'stopcmd' method, and if so runs that; otherwise, looks
            # for the process in the process table.
            # This method will generally not be overridden by submodules.
            def stop
                if self[:stop]
                    return self[:stop]
                elsif self.respond_to?(:stopcmd)
                    self.execute("stop", self.stopcmd)
                else
                    pid = getpid
                    unless pid
                        Puppet.info "%s is not running" % self.name
                        return false
                    end
                    output = %x("kill #{pid} 2>&1")
                    if $? != 0
                        raise Puppet::Error,
                            "Could not kill %s, PID %s: %s" %
                                [self.name, pid, output]
                    end
                    return true
                end
            end

            # Now load any overlay modules to provide additional functionality
            os = Facter["operatingsystem"].value
            case os
            when "Linux":
                case Facter["distro"].value
                when "Debian":
                    require 'puppet/type/service/init'
                    @svctype = Puppet::ServiceTypes::InitSvc

                    # and then require stupid debian-specific stuff
                    require 'puppet/type/service/debian'
                    include Puppet::ServiceTypes::DebianSvc
                end
            when "SunOS":
                release = Float(Facter["operatingsystemrelease"].value)
                if release < 5.10
                    require 'puppet/type/service/init'
                    @svctype = Puppet::ServiceTypes::InitSvc
                else
                    require 'puppet/type/service/smf'
                    @svctype = Puppet::ServiceTypes::SMFSvc
                end
            end
            unless defined? @svctype
                require 'puppet/type/service/base'
                @svctype = Puppet::ServiceTypes::BaseSvc
            end
            include @svctype
		end
	end
end

# $Id$
