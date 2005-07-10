#!/usr/local/bin/ruby -w

# $Id$

require 'puppet/type/state'
require 'puppet/type/pfile'

module Puppet
    # okay, how do we deal with parameters that don't have operations
    # associated with them?
    class State
        # this always runs
        class Returns < Puppet::State
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
            end

            def sync
                tmppath = ENV["PATH"]
                ENV["PATH"] = self.parent[:path]

                # capture both stdout and stderr
                output = %x{#{self.parent[:command]} 2>&1}
                status = $?

                ENV["PATH"] = tmppath

                Puppet.debug("%s: status: %s; returns: %s" %
                    [self.parent[:command],status.exitstatus, self.should]
                )
                if status.exitstatus != self.should
                    Puppet.err("%s returned %s" %
                        [self.parent[:command],status.exitstatus])

                    # and log
                    output.split(/\n/).each { |line|
                        Puppet.info("%s: %s" % [self.parent[:command],line])
                    }
                end

                return :executed_command
            end
        end
    end

    class Type
        class Exec < Type
            attr_reader :command, :user, :returns
            # class instance variable
            
            # this is kind of hackish, using the return value as the
            # state, but apparently namevars can't also be states
            # who knew?
            @states = [
                Puppet::State::Returns
            ]

            @parameters = [
                :path,
                :user,
                :command
            ]

            @name = :exec
            @namevar = :command

            def initialize(hash)
                # default to erroring on a non-zero return
                unless hash.include?("returns") or hash.include?(:returns)
                    hash["returns"] = 0
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
        end
    end
end
