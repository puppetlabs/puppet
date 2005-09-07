# $Id$

require 'etc'
require 'facter'
require 'puppet/type/state'

module Puppet
    class State
        class UserState < Puppet::State
            @@userinfo = nil

            class << self
                attr_accessor :infomethod

                def getinfo(refresh = false)
                    if @@userinfo.nil? or refresh == true
                        begin
                            @@userinfo = Etc.getpwnam(@parent[:name])
                        rescue ArgumentError => detail
                            @@userinfo = :notfound
                        end
                    end

                    @@userinfo
                end
            end

            def retrieve
                info = self.class.getinfo(true)

                method = self.class.infomethod || self.class.name

                unless method
                    raise Puppet::DevError,
                        "Could not retrieve info method for state %s" % self.class.name
                end

                unless info.respond_to?(method)
                    raise Puppet::DevError, "UserInfo object does not respond to %s" %
                        method
                end

                @is = info.send(method)
            end

            def sync
            end
        end

        class UserUID < UserState
            @doc = "The user ID.  Must be specified numerically.  For new users being
                created, if no user ID is specified then one will be chosen
                automatically, which will likely result in the same user having
                different IDs on different systems, which is not recommended."
            @name = :uid
        end

        class UserGID < UserState
            @doc = "The user's primary group.  Can be specified numerically or by name."
            @name = :gid

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

            def sync
                return :executed_command
            end
        end

        class UserComment < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :comment

            def retrieve
            end

            def sync
                return :executed_command
            end
        end

        class UserHome < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :home

            def retrieve
            end

            def sync
                return :executed_command
            end
        end

        class UserShell < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :shell

            def retrieve
            end

            def sync
                return :executed_command
            end
        end

        class UserLocked < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :locked

            def retrieve
            end

            def sync
                return :executed_command
            end
        end

        class UserExpire < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :expire

            def retrieve
            end

            def sync
                return :executed_command
            end
        end

        class UserInactive < UserState
            @doc = "The expected return code.  An error will be returned if the
                executed command returns something else."
            @name = :inactive

            def retrieve
            end

            def sync
                return :executed_command
            end
        end

    end

    class Type
        class User < Type
            @states = [
                Puppet::State::UserUID,
                Puppet::State::UserGID,
                Puppet::State::UserComment,
                Puppet::State::UserHome,
                Puppet::State::UserShell,
                Puppet::State::UserLocked,
                Puppet::State::UserExpire,
                Puppet::State::UserInactive
            ]

            @parameters = [
                :name
            ]

            @doc = "
                "
            @name = :user
            @namevar = :name

            def retrieve
                info = Puppet::State::UserState.getinfo

                if info == :notfound
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
