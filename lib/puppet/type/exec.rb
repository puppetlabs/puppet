module Puppet
    newtype(:exec) do
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
                    cwd => \"/prod/build/dir\"
                }

                . etc. .

                # defined in the test class
                exec { \"make\":
                    cwd => \"/test/build/dir\"
                }

            Any other type would throw an error, complaining that you had
            the same instance being managed in multiple places, but these are
            obviously different images, so ``exec`` had to be treated specially.

            It is recommended to avoid duplicate names whenever possible.
            
            There is a strong tendency to use ``exec`` to do whatever work Puppet
            can't already do; while this is obviously acceptable (and unavoidable)
            in the short term, it is highly recommended to migrate work from ``exec``
            to real Puppet element types as quickly as possible.  If you find that
            you are doing a lot of work with ``exec``, please at least notify
            us at Reductive Labs what you are doing, and hopefully we can work with
            you to get a native element type for the work you are doing.  In general,
            it is a Puppet bug if you need ``exec`` to do your work."

        require 'open3'
        require 'puppet/type/state'

        newstate(:returns) do |state|
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

            # Verify that we have the executable
            def checkexe
                cmd = self.parent[:command]
                if cmd =~ /^\//
                    exe = cmd.split(/ /)[0]
                    unless FileTest.exists?(exe)
                        self.fail(
                            "Could not find executable %s" % exe
                        )
                    end
                    unless FileTest.executable?(exe)
                        self.fail(
                            "%s is not executable" % exe
                        )
                    end
                elsif path = self.parent[:path]
                    exe = cmd.split(/ /)[0]
                    tmppath = ENV["PATH"]
                    ENV["PATH"] = self.parent[:path].join(":")

                    path = %{which #{exe}}.chomp
                    if path == ""
                        self.fail(
                            "Could not find command '%s'" % exe
                        )
                    end
                    ENV["PATH"] = tmppath
                else
                    self.fail(
                        "%s is somehow not qualified with no search path" %
                            self.parent[:command]
                    )
                end
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

                self.checkexe

                # We need a dir to change to, even if it's just the cwd
                dir = self.parent[:cwd] || Dir.pwd
                tmppath = ENV["PATH"]

                event = :executed_command
                begin
                    # Do our chdir
                    Dir.chdir(dir) {
                        if self.parent[:path]
                            ENV["PATH"] = self.parent[:path].join(":")
                        end

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
                            event = :failed_command
                        end

                        # and log
                        @output.split(/\n/).each { |line|
                            self.send(loglevel, line)
                        }
                    }
                rescue Errno::ENOENT => detail
                    self.fail detail.to_s
                ensure
                    # reset things to how we found them
                    ENV["PATH"] = tmppath
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
                @value = values.collect { |val|
                    val.split(":")
                }.flatten
            end
        end

        newparam(:user) do
            desc "The user to run the command as.  Note that if you
                use this then any error output is not currently captured.  This
                is because of a bug within Ruby."

            munge do |user|
                unless Process.uid == 0
                    self.fail "Only root can execute commands as other users"
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
                    self.fail "No such user %s" % user
                end

                return user
            end
        end

        newparam(:group) do
            desc "The group to run the command as.  This seems to work quite
                haphazardly on different platforms -- it is a platform issue
                not a Ruby or Puppet one, since the same variety exists when
                running commnands as different users in the shell."

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
                    self.fail "No such group %s" % group
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
                    self.fail "Directory '%s' does not exist" % dir
                end
                
                dir
            end
        end

        newparam(:refreshonly) do
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
                        require => file[\"/etc/aliases\"],
                        refreshonly => true
                    }
                
                "
        end

        newparam(:creates) do 
            desc "A file that this command creates.  If this
                parameter is provided, then the command will only be run
                if the specified file does not exist.
                
                ::

                    exec { \"tar xf /my/tar/file.tar\":
                        cwd => \"/var/tmp\",
                        creates => \"/var/tmp/myfile\",
                        path => [\"/usr/bin\", \"/usr/sbin\"]
                    }
                
                "

            # FIXME if they try to set this and fail, then we should probably 
            # fail the entire exec, right?
            validate do |file|
                unless file =~ %r{^#{File::SEPARATOR}}
                    self.fail "'creates' files must be fully qualified."
                end
            end
        end

        # Exec names are not isomorphic with the objects.
        @isomorphic = false

        validate do
            # if we're not fully qualified, require a path
            if self[:command] !~ /^\//
                if self[:path].nil?
                    self.fail "both unqualifed and specified no search path"
                end
            end
        end

        autorequire(:file) do
            reqs = []

            # Stick the cwd in there if we have it
            if self[:cwd]
                reqs << self[:cwd]
            end

            tmp = self[:command].dup

            # And search the command line for files, adding any we find.  This
            # will also catch the command itself if it's fully qualified.  It might
            # not be a bad idea to add unqualified files, but, well, that's a
            # bit more annoying to do.
            while tmp.sub!(%r{(#{File::SEPARATOR}\S+)}, '')
                reqs << $1
            end

            reqs
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
