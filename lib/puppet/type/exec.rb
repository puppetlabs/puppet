module Puppet
    newtype(:exec) do
        include Puppet::Util::Execution
        require 'timeout'

        @doc = "Executes external commands.  It is critical that all commands
            executed using this mechanism can be run multiple times without
            harm, i.e., they are *idempotent*.  One useful way to create idempotent
            commands is to use the *creates* parameter.

            It is worth noting that ``exec`` is special, in that it is not
            currently considered an error to have multiple ``exec`` instances
            with the same name.  This was done purely because it had to be this
            way in order to get certain functionality, but it complicates things.
            In particular, you will not be able to use ``exec`` instances that
            share their commands with other instances as a dependency, since
            Puppet has no way of knowing which instance you mean.

            For example::

                # defined in the production class
                exec { \"make\":
                    cwd => \"/prod/build/dir\",
                    path => \"/usr/bin:/usr/sbin:/bin\"
                }

                . etc. .

                # defined in the test class
                exec { \"make\":
                    cwd => \"/test/build/dir\",
                    path => \"/usr/bin:/usr/sbin:/bin\"
                }

            Any other type would throw an error, complaining that you had
            the same instance being managed in multiple places, but these are
            obviously different images, so ``exec`` had to be treated specially.

            It is recommended to avoid duplicate names whenever possible.

            Note that if an ``exec`` receives an event from another resource,
            it will get executed again (or execute the command specified in
            ``refresh``, if there is one).
            
            There is a strong tendency to use ``exec`` to do whatever work Puppet
            can't already do; while this is obviously acceptable (and unavoidable)
            in the short term, it is highly recommended to migrate work from ``exec``
            to native Puppet types as quickly as possible.  If you find that
            you are doing a lot of work with ``exec``, please at least notify
            us at Reductive Labs what you are doing, and hopefully we can work with
            you to get a native element type for the work you are doing."

        require 'open3'
        require 'puppet/type/property'

        # Create a new check mechanism.  It's basically just a parameter that
        # provides one extra 'check' method.
        def self.newcheck(name, &block)
            @checks ||= {}

            check = newparam(name, &block)
            @checks[name] = check
        end

        def self.checks
            @checks.keys
        end

        newproperty(:returns) do |property|
            include Puppet::Util::Execution
            munge do |value|
                value.to_s
            end

            defaultto "0"

            attr_reader :output
            desc "The expected return code.  An error will be returned if the
                executed command returns something else.  Defaults to 0."

            # Make output a bit prettier
            def change_to_s
                return "executed successfully"
            end

            # First verify that all of our checks pass.
            def retrieve
                # Default to somethinng

                if @parent.check
                    self.is = :notrun
                else
                    self.is = self.should
                end
            end

            # Actually execute the command.
            def sync
                olddir = nil

                # We need a dir to change to, even if it's just the cwd
                dir = self.parent[:cwd] || Dir.pwd

                event = :executed_command

                begin
                    @output, status = @parent.run(self.parent[:command])
                rescue Timeout::Error
                    self.fail "Command exceeded timeout" % value.inspect
                end

                loglevel = @parent[:loglevel]
                if status.exitstatus.to_s != self.should.to_s
                    self.fail("%s returned %s instead of %s" %
                        [self.parent[:command], status.exitstatus, self.should.to_s])
                end

                if log = @parent[:logoutput]
                    if log == :true
                        log = @parent[:loglevel]
                    end
                    unless log == :false
                        @output.split(/\n/).each { |line|
                            self.send(log, line)
                        }
                    end
                end

                return event
            end
        end

        newparam(:command) do
            isnamevar
            desc "The actual command to execute.  Must either be fully qualified
                or a search path for the command must be provided.  If the command
                succeeds, any output produced will be logged at the instance's
                normal log level (usually ``notice``), but if the command fails
                (meaning its return code does not match the specified code) then
                any output is logged at the ``err`` log level."
        end

        newparam(:path) do
            desc "The search path used for command execution.
                Commands must be fully qualified if no path is specified.  Paths
                can be specified as an array or as a colon-separated list."

            # Support both arrays and colon-separated fields.
            def value=(*values)
                @value = values.flatten.collect { |val|
                    val.split(":")
                }.flatten
            end
        end

        newparam(:user) do
            desc "The user to run the command as.  Note that if you
                use this then any error output is not currently captured.  This
                is because of a bug within Ruby."

            # Most validation is handled by the SUIDManager class.
            validate do |user|
                unless Puppet::Util::SUIDManager.uid == 0
                    self.fail "Only root can execute commands as other users"
                end
            end
        end

        newparam(:group) do
            desc "The group to run the command as.  This seems to work quite
                haphazardly on different platforms -- it is a platform issue
                not a Ruby or Puppet one, since the same variety exists when
                running commnands as different users in the shell."
            # Validation is handled by the SUIDManager class.
        end

        newparam(:cwd) do
            desc "The directory from which to run the command.  If
                this directory does not exist, the command will fail."

            validate do |dir|
                unless dir =~ /^#{File::SEPARATOR}/
                    self.fail("CWD must be a fully qualified path")
                end
            end

            munge do |dir|
                if dir.is_a?(Array)
                    dir = dir[0]
                end
                
                dir
            end
        end

        newparam(:logoutput) do
            desc "Whether to log output.  Defaults to logging output at the
                loglevel for the ``exec`` element.  Values are **true**, *false*,
                and any legal log level."

            values = [:true, :false]
            # And all of the log levels
            Puppet::Util::Log.eachlevel { |level| values << level }
            newvalues(*values)
        end

        newparam(:refresh) do
            desc "How to refresh this command.  By default, the exec is just
                called again when it receives an event from another resource,
                but this parameter allows you to define a different command
                for refreshing."

            validate do |command|
                @parent.validatecmd(command)
            end
        end

        newparam(:env) do
            desc "Any additional environment variables you want to set for a
                command.  Note that if you use this to set PATH, it will override
                the ``path`` attribute.  Multiple environment variables should be
                specified as an array."

            validate do |values|
                values = [values] unless values.is_a? Array
                values.each do |value|
                    unless value =~ /\w+=/
                        raise ArgumentError, "Invalid environment setting '%s'" % value
                    end
                end
            end
        end
        
        newparam(:timeout) do
            desc "The maximum time the command should take.  If the command takes
                longer than the timeout, the command is considered to have failed
                and will be stopped.  Use any negative number to disable the timeout."
            
            munge do |value|
                value = value.shift if value.is_a?(Array)
                if value.is_a?(String)
                    unless value =~ /^[-\d.]+$/
                        raise ArgumentError, "The timeout must be a number."
                    end
                    Float(value)
                else
                    value
                end
            end
            
            defaultto 300
        end

        newcheck(:refreshonly) do
            desc "The command should only be run as a
                refresh mechanism for when a dependent object is changed.  It only
                makes sense to use this option when this command depends on some
                other object; it is useful for triggering an action::
                    
                    # Pull down the main aliases file
                    file { \"/etc/aliases\":
                        source => \"puppet://server/module/aliases\"
                    }

                    # Rebuild the database, but only when the file changes
                    exec { newaliases:
                        path => [\"/usr/bin\", \"/usr/sbin\"],
                        subscribe => file[\"/etc/aliases\"],
                        refreshonly => true
                    }
                
                Note that only ``subscribe`` can trigger actions, not ``require``,
                so it only makes sense to use ``refreshonly`` with ``subscribe``."

            newvalues(:true, :false)

            # We always fail this test, because we're only supposed to run
            # on refresh.
            def check(value)
                # We have to invert the values.
                if value == :true
                    false
                else
                    true
                end
            end
        end

        newcheck(:creates) do 
            desc "A file that this command creates.  If this
                parameter is provided, then the command will only be run
                if the specified file does not exist::

                    exec { \"tar xf /my/tar/file.tar\":
                        cwd => \"/var/tmp\",
                        creates => \"/var/tmp/myfile\",
                        path => [\"/usr/bin\", \"/usr/sbin\"]
                    }
                
                "

            # FIXME if they try to set this and fail, then we should probably 
            # fail the entire exec, right?
            validate do |files|
                files = [files] unless files.is_a? Array

                files.each do |file|
                    self.fail("'creates' must be set to a fully qualified path") unless file

                    unless file =~ %r{^#{File::SEPARATOR}}
                        self.fail "'creates' files must be fully qualified."
                    end
                end
            end

            # If the file exists, return false (i.e., don't run the command),
            # else return true
            def check(value)
                return ! FileTest.exists?(value)
            end
        end

        newcheck(:unless) do
            desc "If this parameter is set, then this ``exec`` will run unless
                the command returns 0.  For example::
                    
                    exec { \"/bin/echo root >> /usr/lib/cron/cron.allow\":
                        path => \"/usr/bin:/usr/sbin:/bin\",
                        unless => \"grep root /usr/lib/cron/cron.allow 2>/dev/null\"
                    }

                This would add ``root`` to the cron.allow file (on Solaris) unless
                ``grep`` determines it's already there.

                Note that this command follows the same rules as the main command,
                which is to say that it must be fully qualified if the path is not set.
                "

            validate do |cmds|
                cmds = [cmds] unless cmds.is_a? Array

                cmds.each do |cmd|
                    @parent.validatecmd(cmd)
                end
            end

            # Return true if the command does not return 0.
            def check(value)
                begin
                    output, status = @parent.run(value, true)
                rescue Timeout::Error
                    err "Check %s exceeded timeout" % value.inspect
                    return false
                end

                return status.exitstatus != 0
            end
        end

        newcheck(:onlyif) do
            desc "If this parameter is set, then this ``exec`` will only run if
                the command returns 0.  For example::
                    
                    exec { \"logrotate\":
                        path => \"/usr/bin:/usr/sbin:/bin\",
                        onlyif => \"test `du /var/log/messages | cut -f1` -gt 100000\"
                    }

                This would run ``logrotate`` only if that test returned true.

                Note that this command follows the same rules as the main command,
                which is to say that it must be fully qualified if the path is not set.
                "

            validate do |cmds|
                cmds = [cmds] unless cmds.is_a? Array

                cmds.each do |cmd|
                    @parent.validatecmd(cmd)
                end
            end

            # Return true if the command returns 0.
            def check(value)
                begin
                    output, status = @parent.run(value, true)
                rescue Timeout::Error
                    err "Check %s exceeded timeout" % value.inspect
                    return false
                end

                return status.exitstatus == 0
            end
        end

        # Exec names are not isomorphic with the objects.
        @isomorphic = false

        validate do
            validatecmd(self[:command])
        end

        # FIXME exec should autorequire any exec that 'creates' our cwd
        autorequire(:file) do
            reqs = []

            # Stick the cwd in there if we have it
            if self[:cwd]
                reqs << self[:cwd]
            end

            self[:command].scan(/^(#{File::SEPARATOR}\S+)/) { |str|
                reqs << str
            }

            [:onlyif, :unless].each { |param|
                next unless tmp = self[param]

                tmp = [tmp] unless tmp.is_a? Array

                tmp.each do |line|
                    # And search the command line for files, adding any we
                    # find.  This will also catch the command itself if it's
                    # fully qualified.  It might not be a bad idea to add
                    # unqualified files, but, well, that's a bit more annoying
                    # to do.
                    reqs += line.scan(%r{(#{File::SEPARATOR}\S+)})
                end
            }

            # For some reason, the += isn't causing a flattening
            reqs.flatten!

            reqs
        end

        def self.list
            self.collect { |i| i }
        end

        # Verify that we pass all of the checks.  The argument determines whether
        # we skip the :refreshonly check, which is necessary because we now check
        # within refresh()
        def check(refreshing = false)
            self.class.checks.each { |check|
                next if refreshing and check == :refreshonly
                if @parameters.include?(check)
                    val = @parameters[check].value
                    val = [val] unless val.is_a? Array
                    val.each do |value|
                        unless @parameters[check].check(value)
                            return false
                        end
                    end
                end
            }

            return true
        end

        # Verify that we have the executable
        def checkexe(cmd)
            if cmd =~ /^\//
                exe = cmd.split(/ /)[0]
                unless FileTest.exists?(exe)
                    raise ArgumentError, "Could not find executable %s" % exe
                end
                unless FileTest.executable?(exe)
                    raise ArgumentError,
                        "%s is not executable" % exe
                end
            elsif path = self[:path]
                exe = cmd.split(/ /)[0]
                withenv :PATH => self[:path].join(":") do
                    path = %{which #{exe}}.chomp
                    if path == ""
                        raise ArgumentError,
                            "Could not find command '%s'" % exe
                    end
                end
            else
                raise ArgumentError,
                    "%s is somehow not qualified with no search path" %
                        self[:command]
            end
        end

        def output
            if self.property(:returns).nil?
                return nil
            else
                return self.property(:returns).output
            end
        end

        # Run the command, or optionally run a separately-specified command.
        def refresh
            if self.check(true)
                if cmd = self[:refresh]
                    self.run(cmd)
                else
                    self.property(:returns).sync
                end
            end
        end

        # Run a command.
        def run(command, check = false)
            output = nil
            status = nil

            dir = nil

            checkexe(command)

            if dir = self[:cwd]
                unless File.directory?(dir)
                    if check
                        dir = nil
                    else
                        self.fail "Working directory '%s' does not exist" % dir
                    end
                end
            end

            dir ||= Dir.pwd

            if check
                debug "Executing check '#{command}'"
            else
                debug "Executing '#{command}'"
            end
            begin
                # Do our chdir
                Dir.chdir(dir) do
                    env = {}

                    if self[:path]
                        env[:PATH] = self[:path].join(":")
                    end

                    if envlist = self[:env]
                        envlist = [envlist] unless envlist.is_a? Array
                        envlist.each do |setting|
                            if setting =~ /^(\w+)=((.|\n)+)$/
                                name = $1
                                value = $2
                                if env.include? name
                                    warning(
                                    "Overriding environment setting '%s' with '%s'" %
                                        [name, value]
                                    )
                                end
                                env[name] = value
                            else
                                warning "Cannot understand env setting %s" % setting.inspect
                            end
                        end
                    end

                    withenv env do
                        Timeout::timeout(self[:timeout]) do
                            output, status = Puppet::Util::SUIDManager.run_and_capture(
                                [command], self[:user], self[:group]
                            )
                        end
                        # The shell returns 127 if the command is missing.
                        if status.exitstatus == 127
                            raise ArgumentError, output
                        end
                    end
                end
            rescue Errno::ENOENT => detail
                self.fail detail.to_s
            end

            return output, status
        end

        def validatecmd(cmd)
            # if we're not fully qualified, require a path
            if cmd !~ /^\//
                if self[:path].nil?
                    self.fail "'%s' is both unqualifed and specified no search path" % cmd
                end
            end
        end
    end
end

# $Id$
