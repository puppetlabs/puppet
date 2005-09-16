#!/usr/local/bin/ruby -w

# $Id$

require 'facter'
require 'puppet/type/state'

module Puppet
    module CronType
        module Default
            def self.read(user)
                tab = %x{crontab -u #{user} -l 2>/dev/null}
            end

            def self.remove(user)
                %x{crontab -u #{user} -r 2>/dev/null}
            end

            def self.write(user, text)
                IO.popen("crontab -u #{user} -", "w") { |p|
                    p.print text
                }
            end
        end

        module SunOS
            def self.asuser(user)
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

                retval = yield


                if olduid
                    Process.euid = olduid
                end

                return retval
            end

            def self.read(user)
                self.asuser(user) {
                    %x{crontab -l 2>/dev/null}
                }
            end

            def self.remove(user)
                self.asuser(user) {
                    %x{crontab -r 2>/dev/null}
                }
            end

            def self.write(user, text)
                self.asuser(user) {
                    IO.popen("crontab", "w") { |p|
                        p.print text
                    }
                }
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
                unless defined? @is and ! @is.nil?
                    @is = :notfound
                end
            end

            def sync
                @parent.store

                event = nil
                if @is == :notfound
                    #@is = @should
                    event = :cron_created
                elsif @should == :notfound
                    # FIXME I need to actually delete the cronjob...
                    event = :cron_deleted
                elsif @should == @is
                    Puppet.err "Uh, they're both %s" % @should
                    return nil
                else
                    #@is = @should
                    Puppet.err "@is is %s" % @is
                    event = :cron_changed
                end

                @parent.store
                
                return event
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

            @@weekdays = %w{sunday monday tuesday wednesday thursday friday saturday}

            @@months = %w{january february march april may june july
                august september october november december}

            case Facter["operatingsystem"].value
            when "SunOS":
                @crontype = Puppet::CronType::SunOS
            else
                @crontype = Puppet::CronType::Default
            end

            # FIXME so the fundamental problem is, what if the object
            # already exists?

            def self.clear
                @instances = {}
                @loaded = {}
                @synced = {}
                super
            end

            def self.crontype
                return @crontype
            end

            def self.fields
                return [:minute, :hour, :monthday, :month, :weekday, :command]
            end

            def self.instance(obj)
                user = obj[:user]
                if @instances.include?(user)
                    unless @instances[obj[:user]].include?(obj)
                        @instances[obj[:user]] << obj
                    end
                else
                    @instances[obj[:user]] = [obj]
                end
            end

            def self.retrieve(user)
                hash = {}
                name = nil
                unless @instances.include?(user)
                    @instances[user] = []
                end
                #%x{crontab -u #{user} -l 2>/dev/null}.split("\n").each { |line|
                @crontype.read(user).split("\n").each { |line|
                    case line
                    when /^# Puppet Name: (\w+)$/: name = $1
                    when /^#/:
                        # add other comments to the list as they are
                        @instances[user] << line 
                    else
                        ary = line.split(" ")
                        fields().each { |param|
                            value = ary.shift
                            unless value == "*"
                                hash[param] = value
                            end
                        }

                        if ary.length > 0
                            hash[:command] += " " + ary.join(" ")
                        end
                        cron = nil
                        unless name
                            Puppet.info "Autogenerating name for %s" % hash[:command]
                            name = "cron-%s" % hash.object_id
                        end

                        unless hash.include?(:command)
                            raise Puppet::DevError, "No command for %s" % name
                        end
                        unless cron = Puppet::Type::Cron[hash[:command]]
                            cron = Puppet::Type::Cron.create(
                                :name => name
                            )
                        end

                        hash.each { |param, value|
                            cron.is = [param, value]
                        }
                        hash.clear
                        name = nil
                    end
                }
                if $? == 0
                    #return tab
                else
                    #return nil
                end

                @loaded[user] = Time.now
            end

            def self.store(user)
                if @instances.include?(user)
                    @crontype.write(user,
                        @instances[user].collect { |obj|
                            if obj.is_a?(Cron)
                                obj.to_cron
                            else
                                obj.to_s
                            end
                        }.join("\n")
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

            def initialize(hash)
                super
                self.class.instance(self)
            end

            def is=(ary)
                param, value = ary
                if param.is_a?(String)
                    param = param.intern
                end
                if self.class.validstate?(param)
                    self.newstate(param)
                    @states[param].is = value
                else
                    self[param] = value
                end
            end

            def numfix(num)
                if num =~ /^\d+$/
                    return num.to_i
                elsif num.is_a?(Integer)
                    return num
                else
                    return false
                end
            end

            def limitcheck(num, lower, upper, type)
                if num >= lower and num <= upper
                    return num
                else
                    return false
                end
            end

            def alphacheck(value, type, ary)
                tmp = value.downcase
                if tmp.length == 3
                    ary.each_with_index { |name, index|
                        if name =~ /#{tmp}/i
                            return index
                        end
                    }
                else
                    if ary.include?(tmp)
                        return ary.index(tmp)
                    end
                end

                return false
            end

            def parameter(value, type, lower, upper, alpha = nil, ary = nil)
                retval = nil
                if num = numfix(value)
                    retval = limitcheck(num, lower, upper, type)
                elsif alpha
                    retval = alphacheck(value, type, ary)
                end

                if retval
                    @parameters[type] = retval
                else
                    raise Puppet::Error, "%s is not a valid %s" %
                        [value, type]
                end
            end

            def paramminute=(value)
                parameter(value, :minute, 0, 59)
            end

            def paramhour=(value)
                parameter(value, :hour, 0, 23)
            end

            def paramweekday=(value)
                parameter(value, :weekday, 0, 6, true, @@weekdays)
            end

            def parammonth=(value)
                parameter(value, :month, 1, 12, true, @@months)
            end

            def parammonthday=(value)
                parameter(value, :monthday, 1, 31)
            end

            def paramuser=(user)
                require 'etc'

                begin
                    obj = Etc.getpwnam(user)
                rescue ArgumentError
                    raise Puppet::Error, "User %s not found"
                end
                @parameters[:user] = user
            end

            def retrieve
                unless @parameters.include?(:user)
                    raise Puppet::Error, "You must specify the cron user"
                end

                self.class.retrieve(@parameters[:user])
                @states[:command].retrieve
            end

            def store
                self.class.store(@parameters[:user])
            end

            def to_cron
                hash = {:command => @states[:command].should || @states[:command].is }
                self.class.fields().reject { |f| f == :command }.each { |param|
                    hash[param] = @parameters[param] || "*"
                }

                return "# Puppet Name: %s\n" % self.name +
                    self.class.fields.collect { |f|
                        hash[f]
                    }.join(" ")
            end
        end
    end
end
