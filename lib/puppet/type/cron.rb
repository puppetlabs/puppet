#!/usr/local/bin/ruby -w

# $Id$

require 'facter'
require 'puppet/type/state'

module Puppet
    module CronType
        module Default
            def self.read(user)
                %x{crontab -u #{user} -l}
            end

            def self.write(user, text)
                IO.popen("crontab -u #{user} -") { |p|
                    p.print text
                }
            end
        end

        module SunOS
            def self.read(user)
                %x{crontab -l #{user}}
            end

            def self.write(user, text)
                # FIXME this should use our user object, since it already does
                # this for us
                require 'etc'

                begin
                    obj = Etc.getpwnam(user)
                rescue ArgumentError
                    raise Puppet::Error, "User %s not found"
                end

                uid = obj.uid

                olduid = nil
                if Process.uid == uid
                    olduid = Process.uid
                    Process.euid = uid
                end

                IO.popen("crontab -") { |p|
                    p.print text
                }

                if olduid
                    Process.euid = olduid
                end
            end
        end
    end

    class State
        class CronCommand < Puppet::State
            @name = :command
            @doc = "The command to execute in the cron job.  The environment
                provided to the command varies by local system rules, and it is
                best to always provide a fully qualified command.  The user's
                profile is not sourced when the command is run, so if the
                user's environment is desired it should be sourced manually."

            def retrieve
                # nothing...
            end

            def sync
                @parent.store

                if @is == :notfound
                    return :cron_created
                else
                    return :cron_changed
                end
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
                :user,
                :minute,
                :hour,
                :weekday,
                :month,
                :monthday
            ]

            @paramdoc[:name] = "The symbolic name of the cron job.  This name
                is used for human reference only."
            @paramdoc[:user] = "The user to run the command as.  This user must
                be allowed to run cron jobs, which is not currently checked by
                Puppet."
            @paramdoc[:minute] = "The minute at which to run the cron job.
                Optional; if specified, must be between 0 and 59, inclusive."
            @paramdoc[:hour] = "The hour at which to run the cron job. Optional;
                if specified, must be between 0 and 23, inclusive."
            @paramdoc[:weekday] = "The weekday on which to run the command.
                Optional; if specified, must be between 0 and 6, inclusive, with
                0 being Sunday, or must be the name of the day (e.g., Tuesday)."
            @paramdoc[:month] = "The month of the year.  Optional; if specified
                must be between 1 and 12 or the month name (e.g., December)."
            @paramdoc[:monthday] = "The day of the month on which to run the
                command.  Optional; if specified, must be between 1 and 31."

            @doc = "Installs cron jobs.  All fields except the command 
                and the user are optional, although specifying no periodic
                fields would result in the command being executed every
                minute."
            @name = :cron
            @namevar = :name

            @loaded = {}

            @synced = {}

            @instances = {}

            case Facter["operatingsystem"].value
            when "SunOS":
                @crontype = Puppet::CronType::SunOS
            else
                @crontype = Puppet::CronType::Default
            end

            # FIXME so the fundamental problem is, what if the object
            # already exists?

            def self.fields
                return [:minute, :hour, :monthday, :month, :weekday, :command]
            end

            def self.instance(obj)
                @instances << obj
            end

            def self.retrieve(user)
                Puppet.err "Retrieving"
                crons = []
                hash = {}
                #%x{crontab -u #{user} -l 2>/dev/null}.split("\n").each { |line|
                @crontype.read(user).split("\n").each { |line|
                    case line
                    when /^# Puppet Name: (\w+)$/: hash[:name] = $1
                    when /^#/: # add other comments to the list as they are
                        crons << line 
                    else
                        ary = line.split(" ")
                        fields().each { |param|
                            hash[param] = ary.shift
                        }

                        if ary.length > 0
                            hash[:command] += " " + ary.join(" ")
                        end
                        cron = nil
                        unless hash.include?(:name)
                            Puppet.info "Autogenerating name for %s" % hash[:command]
                            hash[:name] = "cron-%s" % hash.object_id
                        end

                        unless cron = Puppet::Type::Cron[hash[:command]]
                            cron = Puppet::Type::Cron.create
                        end

                        hash.each { |param, value|
                            cron.is = [param, value]
                        }
                        crons << cron
                        hash.clear
                    end
                }

                @instances[user] = crons
                @loaded[user] = Time.now
            end

            def self.store(user)
                if @instances.include?(user)
                    @crontype.write(user,
                        @instances[user].join("\n")
                    )
                    @synced[user] = Time.now
                else
                    Puppet.notice "No cron instances for %s" % user
                end
            end

            def self.loaded?(user)
                if @loaded.include?(user)
                    return @loaded[user]
                else
                    return nil
                end
            end

            def self.sync(user)
                Puppet.err ary.length
                str = ary.collect { |obj|
                    Puppet.err obj.name
                    self.to_cron(obj)
                }.join("\n")

                puts str
            end

            def self.to_cron(obj)
                hash = {:command => obj.should(:command)}
                self.fields().reject { |f| f == :command }.each { |param|
                    hash[param] = obj[param] || "*"
                }

                self.fields.collect { |f|
                    hash[f]
                }.join(" ")
            end

            def initialize(hash)
                self.class.instance(self)
                super
            end

            def is=(ary)
                param, value = ary
                if param.is_a?(String)
                    param = param.intern
                end
                unless @states.include?(param)
                    self.newstate(param)
                end
                @states[param].is = value
            end

            def paramuser=(user)
                @parameters[:user] = user
            end

            def retrieve
                unless @parameters.include?(:user)
                    raise Puppet::Error, "You must specify the cron user"
                end

                # look for the existing instance...
                # and then set @is = :notfound
            end

            def store
                self.class.store(@parameters[:user])
            end
        end
    end
end
