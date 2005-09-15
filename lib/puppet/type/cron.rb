#!/usr/local/bin/ruby -w

# $Id$

require 'facter'
require 'puppet/type/state'

module Puppet
    module CronType
        module Default
            def self.fields
                return [:minute, :hour, :weekday, :monthday, :command]
            end

            def self.retrieve(user)
                %x{crontab -u #{user} -l 2>/dev/null}.split("\n").each { |line|
                    hash = {}
                    ary = line.split(" ")
                    fields().each { |param|
                        hash[param] = ary.shift
                    }

                    if ary.length > 0
                        hash[:command] += " " + ary.join(" ")
                    end
                    cron = nil
                    unless cron = Puppet::Type::Cron[hash[:command]]
                        cron = Puppet::Type::Cron.new
                    end

                    hash.each { |param, value|
                        cron.is = [param, value]
                    }
                }
            end

            def self.sync(user)
            end
        end
    end

    class State
        class CronCommand < Puppet::State
            @doc = "The command to execute in the cron job.  The environment
                provided to the command varies by local system rules, and it is
                best to always provide a fully qualified command.  The user's
                profile is not sourced when the command is run, so if the
                user's environment is desired it should be sourced manually."
            @name = :command

            def retrieve
                # nothing...
            end

            def sync
            end
        end
    end

    class Type
        class Cron < Type
            @states = [
                Puppet::State::CronCommand
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

            @loaded = {}

            @synced = {}

            case Facter["operatingsystem"].value
            when "Stub":
                # nothing
            else
                Puppet.err "including default"
                include Puppet::CronType::Default
            end

            def self.loaded?(user)
                if @loaded.include?(user)
                    return @loaded[user]
                else
                    return nil
                end
            end

            def self.sync(user)
            end

            def initialize(hash)
            end

            def is=(ary)
                param, value = ary
                if param.is_a?(String)
                    param = param.intern
                end
                unless @states.include?(param)
                    if stateklass = self.class.validstate?(name) 
                        begin
                        @states[param] = stateklass.new(
                            :parent => self
                        )
                        rescue => detail
                        end
                    else
                        raise Puppet::Error, "Invalid parameter %s" % [name]
                    end

                end
                @states[param].is = value
            end
        end
    end
end
