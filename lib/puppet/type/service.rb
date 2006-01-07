# This is our main way of managing processes right now.
#
# a service is distinct from a process in that services
# can only be managed through the interface of an init script
# which is why they have a search path for initscripts and such

module Puppet

    newtype(:service) do
        @doc = "Manage running services.  Rather than supporting managing
            individual processes, puppet uses init scripts to simplify
            specification of how to start, stop, or test processes.  The
            `path` parameter is provided to enable creation of multiple
            init script directories, including supporting them for normal
            users."
        attr_reader :stat

#        newstate(:enabled) do
#            desc "Whether a service should be enabled to start at boot.
#                **true**/*false*/*runlevel*"
#
#            def retrieve
#                unless @parent.respond_to?(:enabled?)
#                    raise Puppet::Error, "Service %s does not support enabling"
#                end
#                @is = @parent.enabled?
#            end
#
#            munge do |should|
#                @runlevel = nil
#                case should
#                when true: return :enabled
#                when false: return :disabled
#                when /^\d+$/:
#                    @runlevel = should
#                    return :enabled
#                else
#                    raise Puppet::Error, "Invalid 'enabled' value %s" % should
#                end
#            end
#
#            def sync
#                case self.should
#                when :enabled
#                    unless @parent.respond_to?(:enable)
#                        raise Puppet::Error, "Service %s does not support enabling"
#                    end
#                    @parent.enable(@runlevel)
#                    return :service_enabled
#                when :disabled
#                    unless @parent.respond_to?(:disable)
#                        raise Puppet::Error,
#                            "Service %s does not support disabling"
#                    end
#                    @parent.disable
#                    return :service_disabled
#                end
#            end
#        end

        # Handle whether the service should actually be running right now.
        newstate(:running) do
            desc "Whether a service should be running.  **true**/*false*"

            munge do |should|
                case should
                when false,0,"0", "stopped", :stopped:
                    should = :stopped
                when true,1,"1", :running, "running":
                    should = :running
                else
                    self.warning "%s: interpreting '%s' as false" %
                        [self.class,should]
                    should = 0
                end
                self.debug "Service should is %s" % should
                return should
            end

            def retrieve
                self.is = @parent.status
                self.debug "Running value is '%s'" % self.is
            end

            def sync
                event = nil
                case self.should
                when :running
                    @parent.start
                    return :service_started
                when :stopped
                    @parent.stop
                    return :service_stopped
                else
                    self.debug "Not running '%s' and shouldn't be running" %
                        self
                end
            end
        end

        newparam(:type) do
            desc "The service type"

            defaultto { @parent.class.defaulttype }

            # Make sure we've got the actual module, not just a string
            # representing the module.
            munge do |type|
                if type.is_a?(String)
                    type = @parent.class.svctype(type.intern)
                end
                Puppet.debug "Service type is %s" % type.name
                @parent.extend(type)

                return type
            end
        end
        newparam(:binary) do
            desc "The path to the daemon.  This is only used for
                systems that do not support init scripts."
        end
        newparam(:hasstatus) do
            desc "Declare the the service's init script has a
                functional status command.  This is assumed to be default for
                most systems, although there might be platforms on which this is
                assumed to be true."
        end
        newparam(:name) do
            desc "The name of the service to run.  This name
                is used to find the init script in the search path."
            isnamevar
        end
        newparam(:path) do
            desc "The search path for finding init scripts.
                There is currently no default, but hopefully soon there will
                be a reasonable default for all platforms."

            munge do |value|
                paths = []
                if value.is_a?(Array)
                    paths += value.flatten.collect { |p|
                        p.split(":")
                    }.flatten
                else
                    paths = value.split(":")
                end

                paths.each do |path|
                    if FileTest.directory?(path)
                        next
                    end
                    unless FileTest.directory?(path)
                        @parent.info("Search path %s is not a directory" % [path])
                    end
                    unless FileTest.exists?(path)
                        @parent.info("Search path %s does not exist" % [path])
                    end
                    paths.delete(path)
                end

                paths
            end
        end
        newparam(:pattern) do
            desc "The pattern to search for in the process table.
                This is used for stopping services on platforms that do not
                support init scripts, and is also used for determining service
                status on those service whose init scripts do not include a status
                command."
            defaultto { @parent.name }
        end
        newparam(:restart) do
            desc "Specify a *restart* command manually.  If left
                unspecified, the restart method will be determined automatically."
        end
        newparam(:start) do
            desc "Specify a *start* command manually.  If left
                unspecified, the start method will be determined automatically."
        end
        newparam(:status) do
            desc "Specify a *status* command manually.  If left
                unspecified, the status method will be determined automatically."
        end

        newparam(:stop) do
            desc "Specify a *stop* command manually.  If left
                unspecified, the stop method will be determined automatically."
        end

        # Create new subtypes of service management.
        def self.newsvctype(name, parent = nil, &block)
            if parent
                parent = self.svctype(parent)
            end
            svcname = name
            mod = Module.new

            # Add our parent, if it exists
            if parent
                mod.send(:include, parent)
            end

            # And now define the support methods
            code = %{
                def self.name
                    "#{svcname}"
                end

                def self.to_s
                    "SvcType(#{svcname})"
                end

                def svctype
                    "#{svcname}"
                end
            }

            mod.module_eval(code)

            mod.module_eval(&block)

            @modules ||= Hash.new do |hash, key|
                if key.is_a?(String)
                    key = key.intern
                end

                if hash.include?(key)
                    hash[key]
                else
                    nil
                end
            end
            @modules[name] = mod
        end

        # Retrieve a service type.
        def self.svctype(name)
            @modules[name]
        end

        # Retrieve the default type for the current platform.
        def self.defaulttype
            unless defined? @defsvctype
                @defsvctype = nil
                os = Facter["operatingsystem"].value
                case os
                when "Linux":
                    case Facter["distro"].value
                    when "Debian":
                        @defsvctype = self.svctype(:debian)
                    else
                        @defsvctype = self.svctype(:init)
                    end
                when "SunOS":
                    release = Facter["operatingsystemrelease"].value
                    if release.sub(/5\./,'').to_f < 10
                        @defsvctype = self.svctype(:init)
                    else
                        @defsvctype = self.svctype(:smf)
                    end
                end

                unless @defsvctype
                    Puppet.notice "Defaulting to base service type"
                    @defsvctype = self.svctype(:base)
                end
            end

            Puppet.debug "Default service type is %s" % @defsvctype.name

            return @defsvctype
        end

        # Execute a command.  Basically just makes sure it exits with a 0
        # code.
        def execute(type, cmd)
            self.info "Executing %s" % cmd.inspect
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
            unless ps and ps != ""
                raise Puppet::Error,
                    "You must upgrade Facter to a version that includes 'ps'"
            end
            regex = Regexp.new(self[:pattern])
            IO.popen(ps) { |table|
                table.each { |line|
                    if regex.match(line)
                        ary = line.sub(/^\s+/, '').split(/\s+/)
                        return ary[1]
                    end
                }
            }

            return nil
        end

        # Initialize the service.  This is basically responsible for merging
        # in the right module.
        def initialize(hash)
            super

            # and then see if it needs to be checked
            if self.respond_to?(:configchk)
                self.configchk
            end
        end

        # Retrieve the service type.
        def type2module(type)
            self.class.svctype(type)
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
                self.info "Executing %s" % cmd.inspect
                output = %x(#{cmd} 2>&1)
                self.debug "%s status returned %s" %
                    [self.name, output.inspect]
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
                    self.info "%s is not running" % self.name
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
    end
end

# Load all of the different service types.  We could probably get away with
# loading less here, but it's not a big deal to do so.
require 'puppet/type/service/base'
require 'puppet/type/service/init'
require 'puppet/type/service/debian'
require 'puppet/type/service/smf'

# $Id$
