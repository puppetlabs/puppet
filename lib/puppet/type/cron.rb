#!/usr/local/bin/ruby -w

# $Id$

require 'puppet/type/state'

module Puppet
    # okay, how do we deal with parameters that don't have operations
    # associated with them?
    class State
        # this always runs
        class CronCommand < Puppet::State
            @doc = "The command to execute in the cron job.  The environment
                provided to the command varies by local system rules, and it is
                best to always provide a fully qualified command.  The user's
                profile is not sourced when the command is run, so if the
                user's environment is desired it should be sourced manually."
            @name = :command

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

                if self.parent[:refreshonly]
                    # if refreshonly is enabled, then set things so we
                    # won't sync
                    self.is = self.should
                else
                    # else, just set it to something we know it won't be
                    self.is = nil
                end
            end

            def sync
                olddir = nil
                unless self.parent[:cwd].nil?
                    debug "Resetting cwd to %s" % self.parent[:cwd]
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
                    err("%s returned %s" %
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
                        err("Could not reset cwd to %s: %s" %
                            [olddir,detail])
                    end
                end

                return :executed_command
            end
        end
    end

    class Type
        class Cron < Type
            # this is kind of hackish, using the return value as the
            # state, but apparently namevars can't also be states
            # who knew?
            @states = [
                Puppet::State::Returns
            ]

            @parameters = [
                :name,
                :command,
                :user,
                :minute,
                :hour,
                :weekday,
                :monthday
            ]

            @paramdoc[:name] = "The symbolic name of the cron job.  This name
                is used for human reference only and is optional."
            @paramdoc[:user] = "The user to run the command as.  This user
                must be allowed to run cron jobs, which is not currently checked
                by Puppet."
            @paramdoc[:minute] = "The minute at which to run the cron job.
                Optional; if specified, must be between 0 and 59, inclusive."
            @paramdoc[:hour] = "The hour at which to run the cron job. Optional;
                if specified, must be between 0 and 23, inclusive."
            @paramdoc[:weekday] = "The weekday on which to run the command.
                Optional; if specified, must be between 0 and 6, inclusive, with
                0 being Sunday."
            @paramdoc[:monthday] = "The day of the month on which to run the
                command.  Optional; if specified, must be between 0 and 31."

            @doc = "Installs cron jobs.  All fields except the command 
                and the user are optional, although specifying no periodic
                fields would result in the command being executed every
                minute."
            @name = :cron
            @namevar = :name

            def initialize(hash)
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
end
