# $Id$

require 'etc'
require 'facter'
require 'puppet/type/state'

module Puppet
    class State
        class UserState < Puppet::State
            class << self
                attr_accessor :flag
                def infomethod
                    if defined? @infomethod and @infomethod
                        return @infomethod
                    else
                        return @name
                    end
                end
            end

            def create
                obj = @parent.getinfo
                
                cmd = nil
                event = nil
                if @should == :notfound
                    # we need to remove the object...
                    if obj.nil?
                        # the user already doesn't exist
                        return nil
                    end

                    cmd = ["userdel", @parent.name]
                    type = "delete"
                else
                    unless obj.nil?
                        raise Puppet::DevError,
                            "Got told to create a user that already exists"
                    end
                    # we're creating the user

                    # i can just tell i'm going to regret this
                    # why doesn't POSIX include interfaces for adding users
                    # and groups? it's stupid
                    cmd = ["useradd"]
                    @parent.eachstate { |state|
                        # the value needs to be quoted, mostly because -c might
                        # have spaces in it
                        cmd << state.class.flag << "'%s'" % state.should
                    }
                    cmd << @parent.name
                    type = "create"
                end

                output = %x{#{cmd.join(" ")} 2>&1}

                unless $? == 0
                    raise Puppet::Error, "Could not %s group %s: %s" %
                        [type, @parent.name, output]
                end

                return "user_#{type}d".intern
            end

            def retrieve
                if info = @parent.getinfo(true)
                    @is = info.send(self.class.infomethod)
                else
                    @is = :notfound
                end
            end

            def sync
                obj = @parent.getinfo

                # if the user either does not or should not exist...
                # yes, it's a badly named method
                if obj.nil? or @should == :notfound
                    return self.create
                end

                # there's a possibility that we created the user in this session
                # so verify that we're actually out of sync
                if self.insync?
                    return nil
                end
                cmd = [
                    "usermod", self.class.flag, "'%s'" % @should, @parent.name
                ].join(" ")

                output = %x{#{cmd} 2>&1}

                unless $? == 0
                    raise Puppet::Error, "Could not modify %s on user %s: %s" %
                        [self.class.name, @parent.name, output]
                end

                return :user_modified
            end
        end

        class UserUID < UserState
            @doc = "The user ID.  Must be specified numerically.  For new users being
                created, if no user ID is specified then one will be chosen
                automatically, which will likely result in the same user having
                different IDs on different systems, which is not recommended."
            @name = :uid
            @flag = "-u"
        end

        class UserGID < UserState
            @doc = "The user's primary group.  Can be specified numerically or by name."
            @name = :gid
            @flag = "-g"

            def should=(gid)
                method = :getgrgid
                if gid.is_a?(String)
                    if gid =~ /^[0-9]+$/
                        gid = Integer(gid)
                    else
                        method = :getgrnam
                    end
                end

                # FIXME this should really check to see if we already have a group
                # ready to be managed; if so, then we should just mark it as a prereq
                begin
                    ginfo = Etc.send(method, gid)
                rescue ArgumentError => detail
                    raise Puppet::Error, "Could not find group %s: %s" % [gid, detail]
                end

                @should = ginfo.gid
            end
        end

        class UserComment < UserState
            @doc = "A description of the user.  Generally is a user's full name."
            @name = :comment
            @infomethod = :gecos
            @flag = "-c"
        end

        class UserHome < UserState
            @doc = "The home directory of the user.  The directory must be created
                separately and is not currently checked for existence."
            @name = :home
            @infomethod = :dir
            @flag = "-d"
        end

        class UserShell < UserState
            @doc = "The user's login shell.  The shell must exist and be
                executable."
            @name = :shell
            @flag = "-s"
        end

        # these three states are all implemented differently on each platform, so i'm
        # disabling them for now

        # FIXME Puppet::State::UserLocked is currently non-functional
        class UserLocked < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :locked
        end

        # FIXME Puppet::State::UserExpire is currently non-functional
        class UserExpire < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :expire
            @flag = "-e"
        end

        # FIXME Puppet::State::UserInactive is currently non-functional
        class UserInactive < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :inactive
            @flag = "-f"
        end

    end

    class Type
        class User < Type
            @states = [
                Puppet::State::UserUID,
                Puppet::State::UserGID,
                Puppet::State::UserComment,
                Puppet::State::UserHome,
                Puppet::State::UserShell
            ]

            @parameters = [
                :name
            ]

            @paramdoc[:name] = "User name.  While limitations are determined for
                each operating system, it is generally a good idea to keep to the
                degenerate 8 characters, beginning with a letter."

            @doc = "Manage users.  Currently can create and modify users, but cannot
                delete them.  Theoretically all of the parameters are optional,
                but if no parameters are specified the comment will be set to the
                user name in order to make the internals work out correctly."
            @name = :user
            @namevar = :name

            def getinfo(refresh = false)
                if @userinfo.nil? or refresh == true
                    begin
                        @userinfo = Etc.getpwnam(self[:name])
                    rescue ArgumentError => detail
                        @userinfo = nil
                    end
                end

                @userinfo
            end

            def initialize(hash)
                @userinfo = nil
                super

                if @states.empty?
                    self[:comment] = self[:name]
                end
            end

            def retrieve
                info = self.getinfo(true)

                if info.nil?
                    # the user does not exist
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
