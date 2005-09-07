# $Id$

require 'etc'
require 'facter'
require 'puppet/type/state'

module Puppet
    class State
        class GroupState < Puppet::State
            class << self
                def infomethod
                    if defined? @infomethod and @infomethod
                        return @infomethod
                    else
                        return @name
                    end
                end
            end

            def retrieve
                obj = @parent.getinfo(true)

                method = self.class.infomethod

                @is = obj.send(method)
            end

            def sync
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

        class GroupGID < GroupState
            @doc = "The group ID.  Must be specified numerically.  If not specified,
                a number will be picked, which can result in ID differences across
                systems and thus is not recommended.  The method for picking GIDs
                is basically to find the next GID above the highest existing GID
                excluding those above 65000."
            @name = :gid

            def should=(gid)
                if gid.is_a?(String)
                    if gid =~ /^[0-9]+$/
                        gid = Integer(gid)
                    end
                end

                Puppet.info "Setting gid to %s" % gid

                @should = gid
            end
        end
    end

    class Type
        class Group < Type
            @states = [
                Puppet::State::GroupGID
            ]

            @parameters = [
                :name
            ]

            @doc = " "
            @name = :group
            @namevar = :name

            def getinfo(refresh = false)
                if @groupinfo.nil? or refresh == true
                    begin
                        @groupinfo = Etc.getgrnam(self[:name])
                    rescue ArgumentError => detail
                        # leave groupinfo as nil
                    end
                end

                @groupinfo
            end

            def initialize(hash)
                @groupinfo = nil
                super
            end

            def retrieve
                obj = self.getinfo(true)

                if obj.nil?
                    # the group does not exist

                    # unless we're in noop mode, we need to auto-pick a gid if there
                    # hasn't been one specified
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
                else
                    super
                end
            end
        end
    end
end
