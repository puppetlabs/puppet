module Puppet
    newtype(:exec) do
        @doc = "Executes external commands.  It is critical that all commands
            executed using this mechanism can be run multiple times without
            harm, i.e., they are *idempotent*.  One useful way to create idempotent
            commands is to use the *creates* parameter.

            It is worth nothing that ``exec`` is special, in that it is not
            currently considered an error to have multiple ``exec`` instances
            with the same name.  This was done purely because it had to be this
            way in order to get certain functionality, but it complicates things.
            In particular, you will not be able to use ``exec`` instances that
            share their commands with other instances as a dependency, since
            Puppet has no way of knowing which instance you mean.

            It is recommended to avoid duplicate names whenever possible."

        require 'open3'
        require 'puppet/type/state'

        newstate(:returns) do |state|
            munge do |value|
                value.to_s
            end

            defaultto "0"

            attr_reader :output
            desc "The expected return code.  An error will be returned if the
                executed command returns something else."

            # Make output a bit prettier
            def change_to_s
                return "executed successfully"
            end

            # because this command always runs,
            # we're just using retrieve to verify that the command
            # exists and such
            def retrieve
                if file = @parent[:creates]
                    if FileTest.exists?(file)
                        @is = true
                        @should = [true]
                        return
                    end
                end

                cmd = self.parent[:command]
                if cmd =~ /^\//
                    exe = cmd.split(/ /)[0]
                    unless FileTest.exists?(exe)
                        raise TypeError.new(
                            "Could not find executable %s" % exe
                        )
                    end
                    unless FileTest.executable?(exe)
                        raise TypeError.new(
                            "%s is not executable" % exe
                        )
                    end
                elsif path = self.parent[:path]
                    exe = cmd.split(/ /)[0]
                    tmppath = ENV["PATH"]
                    ENV["PATH"] = self.parent[:path]

                    path = %{which #{exe}}.chomp
                    if path == ""
                        raise TypeError.new(
                            "Could not find command '%s'" % exe
                        )
                    end
                    ENV["PATH"] = tmppath
                else
                    raise TypeError.new(
                        "%s is somehow not qualified with no search path" %
                            self.parent[:command]
                    )
                end

                if self.parent[:refreshonly]
                    # if refreshonly is enabled, then set things so we
                    # won't sync
                    self.is = self.should
                else
                    # else, just set it to something we know it won't be
                    self.is = nil
                end
            end

            # Actually execute the command.
            def sync
                olddir = nil

                # We need a dir to change to, even if it's just the cwd
                dir = self.parent[:cwd] || Dir.pwd
                tmppath = ENV["PATH"]

                begin
                    # Do our chdir
                    Dir.chdir(dir) {
                        ENV["PATH"] = self.parent[:path]

                        # The user and group default to nil, which 'asuser'
                        # handlers correctly
                        Puppet::Util.asuser(@parent[:user], @parent[:group]) {
                            # capture both stdout and stderr
                            if @parent[:user]
                                unless defined? @@alreadywarned
                                    Puppet.warning(
                            "Cannot capture STDERR when running as another user"
                                    )
                                    @@alreadywarned = true
                                end
                                @output = %x{#{self.parent[:command]}}
                            else
                                @output = %x{#{self.parent[:command]} 2>&1}
                            end
                        }
                        status = $?

                        loglevel = @parent[:loglevel]
                        if status.exitstatus.to_s != self.should.to_s
                            err("%s returned %s" %
                                [self.parent[:command],status.exitstatus])

                            # if we've had a failure, up the log level
                            loglevel = :err
                        end

                        # and log
                        @output.split(/\n/).each { |line|
                            self.send(loglevel, line)
                        }
                    }
                rescue Errno::ENOENT => detail
                    raise Puppet::Error, detail.to_s
                ensure
                    # reset things to how we found them
                    ENV["PATH"] = tmppath
                end

                return :executed_command
            end
        end

        newparam(:command) do
            isnamevar
            desc "The actual command to execute."
        end

        newparam(:path) do
            desc "The search path used for command execution.
                Commands must be fully qualified if no path is specified."
        end

        newparam(:user) do
            desc "The user to run the command as.  Note that if you
                use this then any error output is not currently captured.  This
                is mostly because of a bug within Ruby."

            munge do |user|
                unless Process.uid == 0
                    raise Puppet::Error,
                        "Only root can execute commands as other users"
                end
                require 'etc'

                method = :getpwnam
                case user
                when Integer
                    method = :getpwuid
                when /^\d+$/
                    user = user.to_i
                    method = :getpwuid
                end
                begin
                    Etc.send(method, user)
                rescue ArgumentError
                    raise Puppet::Error, "No such user %s" % user
                end

                return user
            end
        end

        newparam(:group) do
            desc "The group to run the command as."

            # Execute the command as the specified group
            munge do |group|
                require 'etc'
                method = :getgrnam
                case group
                when Integer: method = :getgrgid
                when /^\d+$/
                    group = group.to_i
                    method = :getgrgid
                end

                begin
                    Etc.send(method, group)
                rescue ArgumentError
                    raise Puppet::Error, "No such group %s" % group
                end

                group
            end
        end

        newparam(:cwd) do
            desc "The directory from which to run the command.  If
                this directory does not exist, the command will fail."

            munge do |dir|
                if dir.is_a?(Array)
                    dir = dir[0]
                end

                unless File.directory?(dir)
                    raise Puppet::Error, "Directory '%s' does not exist" % dir
                end
                
                dir
            end
        end

        newparam(:refreshonly) do
            desc "The command should only be run as a
                refresh mechanism for when a dependent object is changed."
        end

        newparam(:creates) do 
            desc "A file that this command creates.  If this
                parameter is provided, then the command will only be run
                if the specified file does not exist."

            # FIXME if they try to set this and fail, then we should probably 
            # fail the entire exec, right?
            validate do |file|
                unless file =~ %r{^#{File::SEPARATOR}}
                    raise Puppet::Error, "'creates' files must be fully qualified."
                end
            end
        end

        # Exec names are not isomorphic with the objects.
        @isomorphic = false

        validate do
            # if we're not fully qualified, require a path
            if self[:command] !~ /^\//
                if self[:path].nil?
                    raise TypeError,
                        "both unqualifed and specified no search path"
                end
            end
        end

        def output
            if self.state(:returns).nil?
                return nil
            else
                return self.state(:returns).output
            end
        end

        # this might be a very, very bad idea...
        def refresh
            self.state(:returns).sync
        end

        def to_s
            "exec(%s)" % self.name
        end
    end
end

# $Id$
