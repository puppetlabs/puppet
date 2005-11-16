#!/usr/local/bin/ruby -w

# $Id$

require 'puppet/type/state'

module Puppet
    # okay, how do we deal with parameters that don't have operations
    # associated with them?
    class State
        # this always runs
        class Returns < Puppet::State
            attr_reader :output

            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :returns

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

                            stderr = Puppet::Util.capture_stderr {
                                @output = %x{#{self.parent[:command]}}
                            }

                            if stderr != ""
                                stderr.split(/\n/).each { |line|
                                    self.send(:err, line)
                                }
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
    end

    class Type
        class Exec < Type
            # this is kind of hackish, using the return value as the
            # state, but apparently namevars can't also be states
            # who knew?
            @states = [
                Puppet::State::Returns
            ]

            @parameters = [
                :path,
                :user,
                :group,
                :creates,
                :cwd,
                :refreshonly,
                :command
            ]

            @paramdoc[:path] = "The search path used for command execution.
                Commands must be fully qualified if no path is specified."
            @paramdoc[:user] = "The user to run the command as."
            @paramdoc[:group] = "The group to run the command as."
            @paramdoc[:cwd] = "The directory from which to run the command.  If
                this directory does not exist, the command will fail."
            @paramdoc[:refreshonly] = "The command should only be run as a
                refresh mechanism for when a dependent object is changed."
            @paramdoc[:command] = "The actual command to execute."
            @paramdoc[:creates] = "A file that this command creates.  If this
                parameter is provided, then the command will only be run
                if the specified file does not exist."

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
            @name = :exec
            @namevar = :command

            # Exec names are not isomorphic with the objects.
            @isomorphic = false

            def initialize(hash)
                # default to erroring on a non-zero return
                if hash.include?("returns") 
                    if hash["returns"].is_a?(Fixnum)
                        hash["returns"] = hash["returns"].to_s
                    end
                elsif hash.include?(:returns) 
                    if hash[:returns].is_a?(Fixnum)
                        hash[:returns] = hash[:returns].to_s
                    end
                else
                    hash[:returns] = "0"
                end

                super

                if self[:command].nil?
                    raise TypeError.new("Somehow the command is nil")
                end

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

            # FIXME if they try to set this and fail, then we should probably 
            # fail the entire exec, right?
            def paramcreates=(file)
                unless file =~ %r{^#{File::SEPARATOR}}
                    raise Puppet::Error, "'creates' files must be fully qualified."
                end
                @parameters[:creates] = file
            end

            def paramcwd=(dir)
                if dir.is_a?(Array)
                    dir = dir[0]
                end

                unless File.directory?(dir)
                    raise Puppet::Error, "Directory '%s' does not exist" % dir
                end

                @parameters[:cwd] = dir
            end

            # Execute the command as the specified group
            def paramgroup=(group)
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

                @parameters[:group] = group
            end

            # Execute the command as the specified user
            def paramuser=(user)
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

                @parameters[:user] = user
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
end
