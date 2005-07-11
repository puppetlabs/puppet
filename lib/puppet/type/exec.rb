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

            @name = :returns

            # because this command always runs,
            # we're just using retrieve to verify that the command
            # exists and such
            def retrieve
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
                self.is = nil
            end

            def sync
                olddir = nil
                unless self.parent[:cwd].nil?
                    Puppet.debug "Resetting cwd to %s" % self.parent[:cwd]
                    olddir = Dir.getwd
                    begin
                        Dir.chdir(self.parent[:cwd])
                    rescue => detail
                        raise "Failed to set cwd: %s" % detail
                    end
                end

                tmppath = ENV["PATH"]
                ENV["PATH"] = self.parent[:path]

                # capture both stdout and stderr
                @output = %x{#{self.parent[:command]} 2>&1}
                status = $?

                loglevel = :info
                if status.exitstatus.to_s != self.should.to_s
                    Puppet.err("%s returned %s" %
                        [self.parent[:command],status.exitstatus])

                    # if we've had a failure, up the log level
                    loglevel = :err
                end

                # and log
                @output.split(/\n/).each { |line|
                    Puppet.send(loglevel, "%s: %s" % [self.parent[:command],line])
                }

                # reset things to how we found them
                ENV["PATH"] = tmppath

                unless olddir.nil?
                    begin
                        Dir.chdir(olddir)
                    rescue => detail
                        Puppet.err("Could not reset cwd to %s: %s" %
                            [olddir,detail])
                    end
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
                :cwd,
                :command
            ]

            @name = :exec
            @namevar = :command

            def initialize(hash)
                # default to erroring on a non-zero return
                if hash.include?("returns") 
                    if hash["returns"].is_a?(Fixnum)
                        hash["returns"] = hash["returns"].to_s
                    end
                elsif hash.include?(:returns) 
                    if hash["returns"].is_a?(Fixnum)
                        hash[:returns] = hash[:returns].to_s
                    end
                else
                    Puppet.debug("setting return to 0")
                    hash[:returns] = "0"
                end

                super

                if self[:command].nil?
                    raise TypeError.new("Somehow the command is nil")
                end

                # if we're not fully qualified, require a path
                if self[:command] !~ /^\//
                    if self[:path].nil?
                        error = TypeError.new(
                            "'%s' is both unqualifed and specified no search path" %
                                self[:command]
                        )
                        raise error
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
        end
    end
end
