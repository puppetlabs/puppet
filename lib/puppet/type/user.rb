# $Id$

require 'etc'
require 'facter'
require 'puppet/type/state'

module Puppet
    class State
        module UserUID
            def self.doc
                "The user ID.  Must be specified numerically.  For new users
                being created, if no user ID is specified then one will be
                chosen automatically, which will likely result in the same user
                having different IDs on different systems, which is not
                recommended."
            end

            def self.name
                :uid
            end
        end

        module UserGID
            def self.doc
                "The user's primary group.  Can be specified numerically or
                by name."
            end

            def self.name
                :gid
            end

            def should=(gid)
                method = :getgrgid
                if gid.is_a?(String)
                    if gid =~ /^[0-9]+$/
                        gid = Integer(gid)
                    else
                        method = :getgrnam
                    end
                end

                # FIXME this should really check to see if we already have a
                # group ready to be managed; if so, then we should just mark it
                # as a prereq
                begin
                    ginfo = Etc.send(method, gid)
                rescue ArgumentError => detail
                    raise Puppet::Error, "Could not find group %s: %s" %
                        [gid, detail]
                end

                @should = ginfo.gid
            end
        end

        module UserComment
            def self.doc
                "A description of the user.  Generally is a user's full name."
            end

            def self.name
                :comment
            end

            def self.posixmethod
                :gecos
            end
        end

        module UserHome
            def self.doc
                "The home directory of the user.  The directory must be created
                separately and is not currently checked for existence."
            end

            def self.name
                :home
            end

            def self.posixmethod
                :dir
            end
        end

        module UserShell
            def self.doc
                "The user's login shell.  The shell must exist and be
                executable."
            def self.name
                :shell
            end
        end

        # these three states are all implemented differently on each platform,
        # so i'm disabling them for now

        # FIXME Puppet::State::UserLocked is currently non-functional
        module UserLocked 
            def self.doc
                "The expected return code.  An error will be returned if the
                executed command returns something else."
            end

            def self.name
                :locked
            end
        end

        # FIXME Puppet::State::UserExpire is currently non-functional
        module UserExpire 
            def self.doc
                "The expected return code.  An error will be returned if the
                executed command returns something else."
            end

            def self.name; :expire; end
        end

        # FIXME Puppet::State::UserInactive is currently non-functional
        module UserInactive 
            def self.doc
                "The expected return code.  An error will be returned if the
                executed command returns something else."
            end

            def self.name; :inactive; end
        end

    end

    class Type
        class User < Type
            statemodule = nil
            case Facter["operatingsystem"].value
            when "Darwin":
                statemodule = Puppet::NameService::NetInfo::NetInfoUser
            else
                statemodule = Puppet::NameService::ObjectAdd::ObjectAddUser
            end

            @states = statemodule.substates

            @parameters = [
                :name
            ]

            @paramdoc[:name] = "User name.  While limitations are determined for
                each operating system, it is generally a good idea to keep to the
                degenerate 8 characters, beginning with a letter."

            @doc = "Manage users.  Currently can create and modify users, but
                cannot delete them.  Theoretically all of the parameters are
                optional, but if no parameters are specified the comment will
                be set to the user name in order to make the internals work out
                correctly."
            @name = :user
            @namevar = :name

            @netinfodir = "users"

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
