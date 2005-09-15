# $Id$

require 'etc'
require 'facter'
require 'puppet/type/state'

module Puppet
    class State
        class GroupState < Puppet::State
            attr_accessor :xaddflag, :ninfoarg, :infomethod
            class << self
                [:infomethod, :ninfokey, :xaddflag].each { |method|
                    self.send(:define_method, method) {
                        # *shudder*
                        if eval("defined? @%s" % method) and eval("@%s" % method)
                            return eval("@%s" % method)
                        else
                            return @name
                        end
                    }
                }
            end

            # we use the POSIX interfaces to retrieve all information,
            # so we don't have to worry about abstracting that across
            # the system
            def retrieve
                if obj = @parent.getinfo(true)

                    method = self.class.infomethod
                    @is = obj.send(method)
                else
                    @is = :notfound
                end

            end
        end

        class GroupGID < GroupState
            @doc = "The group ID.  Must be specified numerically.  If not
                specified, a number will be picked, which can result in ID
                differences across systems and thus is not recommended.  The
                method for picking GIDs is basically to find the next GID above
                the highest existing GID excluding those above 65000."
            @name = :gid
            @xaddflag = "-g"

            def should=(gid)
                if gid.is_a?(String)
                    if gid =~ /^[0-9]+$/
                        gid = Integer(gid)
                    else
                        raise Puppet::Error, "Invalid GID %s" % gid
                    end
                end

                if gid.is_a?(Integer) and gid < 0
                    raise Puppet::Error, "GIDs must be positive"
                end

                Puppet.info "Setting gid to %s" % gid

                @should = gid
            end
        end

        class GroupName < GroupState
            @doc = "The group name.  While naming limitations vary by
                system, it is advisable to keep the name to the degenerate
                limitations, which is a maximum of 8 characters beginning with
                a letter."
            @name = :name

            def should=(name)
                Puppet.info "Setting group name to %s" % name

                @should = name
            end
        end

        module GroupXAdd
            def self.test
                system("which groupadd > /dev/null 2>&1")

                if $? == 0
                    return true
                else
                    Puppet.err "Could not find groupadd"
                    return false
                end
            end

            def sync
                obj = @parent.getinfo

                if self.name == :name
                    return syncname()
                end

                obj = @parent.getinfo

                if obj.nil?
                    raise Puppet::DevError,
                        "Group does not exist; cannot set gid"
                end

                if @should == :notfound
                    # we have to depend on the 'name' state doing the deletion
                    return nil
                end
                cmd = [
                    "groupmod", self.class.xaddflag, "'%s'" % @should, @parent.name
                ].join(" ")

                output = %x{#{cmd} 2>&1}

                unless $? == 0
                    raise Puppet::Error, "Could not modify %s on group %s: %s" %
                        [self.class.name, @parent.name, output]
                end

                return :group_modified
            end

            private
            def syncname
                obj = @parent.getinfo
                
                cmd = nil
                event = nil
                if @should == :notfound
                    # we need to remove the object...
                    if obj.nil?
                        # the group already doesn't exist
                        return nil
                    end

                    cmd = ["groupdel", @parent.name]
                    type = "delete"
                else
                    unless obj.nil?
                        raise Puppet::DevError,
                            "Got told to create a group that already exists"
                    end
                    # we're creating the group

                    # i can just tell i'm going to regret this
                    # why doesn't POSIX include interfaces for adding users
                    # and groups? it's stupid
                    cmd = ["groupadd"]
                    if gid = @parent.should(:gid)
                        cmd << "-g" << gid 
                    end
                    cmd << @parent.name
                    type = "create"
                end

                output = %x{#{cmd.join(" ")} 2>&1}

                unless $? == 0
                    raise Puppet::Error, "Could not %s group %s: %s" %
                        [type, @parent.name, output]
                end

                return "group_#{type}d".intern
            end
        end

        module GroupNInfo
            def self.test
                system("which niutil > /dev/null 2>&1")

                if $? == 0
                    return true
                else
                    Puppet.err "Could not find niutil"
                    return false
                end
            end

            def self.flush
                output = %x{lookupd -flushcache 2>&1}

                if $? != 0
                    Puppet.err "Could not flush lookupd cache: %s" % output
                end
            end

            def retrieve
                cmd = %w{nireport / /groups name}

                if key = self.class.ninfokey
                    cmd << key.to_s
                else
                    raise Puppet::DevError,
                        "Could not find ninfokey for state %s" %
                        self.class.name
                end

                output = %x{#{cmd.join(" ")} 2>&1}.split("\n").each { |line|
                    name, value = line.chomp.split(/\s+/)

                    if name == @parent.name
                        if value =~ /^\d+$/
                            @is = Integer(value)
                        else
                            @is = value
                        end
                    end
                }

                unless defined? @is
                    @is = :notfound
                end
            end

            def sync
                events = []

                unless @parent.exists?
                    events << syncname()
                end

                if @should == :notfound
                    return syncname()
                end
                obj = @parent.getinfo

                if obj.nil?
                    raise Puppet::DevError,
                        "Group does not exist; cannot set gid"
                end

                cmd = ["niutil"]

                cmd << "-createprop" << "/" << "/groups/%s" % @parent.name

                if key = self.class.ninfokey
                    cmd << key << "'%s'" % @should
                else
                    raise Puppet::DevError,
                        "Could not find ninfokey for state %s" %
                        self.class.name
                end

                output = %x{#{cmd.join(" ")} 2>&1}

                unless $? == 0
                    raise Puppet::Error, "Could not set %s on group %s: %s" %
                        [self.class.name, @parent.name, output]
                end

                GroupNInfo.flush()

                events << :group_modified
                return events
            end

            private
            def syncname
                
                cmd = ["niutil"]
                event = nil
                if @should == :notfound
                    # we need to remove the object...
                    unless @parent.exists?
                        # the group already doesn't exist
                        return nil
                    end

                    cmd << "-destroy"
                    type = "delete"
                else
                    if @parent.exists?
                        raise Puppet::DevError,
                            "Got told to create a group that already exists"
                    end
                    # we're creating the group

                    # i can just tell i'm going to regret this
                    # why doesn't POSIX include interfaces for adding users
                    # and groups? it's stupid
                    cmd << "-create"
                    type = "create"
                end

                cmd << "/" << "/groups/%s" % @parent.name

                output = %x{#{cmd.join(" ")} 2>&1}

                unless $? == 0
                    raise Puppet::Error, "Could not %s group %s: %s" %
                        [type, @parent.name, output]
                end

                GroupNInfo.flush()

                return "group_#{type}d".intern
            end
        end
    end

    class Type
        class Group < Type
            @states = [
                    Puppet::State::GroupGID
            ]

            @@extender = nil
            case Facter["operatingsystem"].value
            when "Darwin":
                @@extender = "NInfo"
            else
                @@extender = "XAdd"
            end

            @name = :group
            @namevar = :name

            # all of the states are very similar, but syncing is different
            # for each _type_ of state
            @states.each { |state|
                begin
                    klass = eval("Puppet::State::Group" + @@extender)
                    if klass.test
                        state.send(:include, klass)
                    else
                        Puppet.err "Cannot sync %s on %s" %
                            [state.name, @name]
                    end
                rescue NameError
                    Puppet.notice "No %s extender for %s" %
                        [@@extender, state.name]
                end
            }

            @parameters = [:name]

            @paramdoc[:name] = "The group name.  While naming limitations vary by
                system, it is advisable to keep the name to the degenerate
                limitations, which is a maximum of 8 characters beginning with
                a letter."

            @doc = "Manage groups.  This type can only create groups.  Group
                membership must be managed on individual users."


            def exists?
                case @@extender
                when "NInfo":
                    cmd = "nidump -r /groups/%s /" % self.name
                    output = %x{#{cmd} 2>/dev/null}
                    if output == ""
                        return false
                    else
                        return true
                    end
                else
                    if self.getinfo
                        return true
                    else
                        return false
                    end
                end
            end

            def getinfo(refresh = false)
                if @groupinfo.nil? or refresh == true
                    begin
                        #GroupNInfo.flush()
                        system("lookupd -flushcache")
                        #sleep(4)
                        @groupinfo = Etc.getgrnam(self.name)
                    rescue ArgumentError => detail
                        @groupinfo = nil
                    end
                end

                @groupinfo
            end

            def initialize(hash)
                @groupinfo = nil
                super
            end

            def retrieve
                if self.exists?
                    super
                else
                    # the group does not exist

                    # unless we're in noop mode, we need to auto-pick a gid if
                    # there hasn't been one specified
                    unless @states.include?(:gid) or self.noop
                        highest = 0
                        Etc.group { |group|
                            if group.gid > highest
                                unless group.gid > 65000
                                    highest = group.gid
                                end
                            end
                        }

                        self[:gid] = highest + 1
                    end

                    @states.each { |name, state|
                        state.is = :notfound
                    }

                    return
                end
            end
        end
    end
end
