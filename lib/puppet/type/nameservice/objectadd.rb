module Puppet
    class Type
        def self.objectaddflag
            if defined? @objectaddflag and @objectaddflag
                return @objectaddflag
            else
                return @name
            end
        end
    end

    module NameService
        module ObjectAdd
            # Verify that we've got the commands necessary to manage flat files.
            def self.test
                system("which groupadd > /dev/null 2>&1")

                if $? == 0
                    return true
                else
                    Puppet.err "Could not find groupadd"
                    return false
                end
            end

            class ObjectAddGroup < POSIX::POSIXState
                def addcmd
                    cmd = ["groupadd"]
                    if gid = @parent.should(:gid)
                        cmd << "-g" << gid 
                    end

                    return cmd.join(" ")
                end

                def deletecmd
                    "groupdel %s" % @parent.name
                end

                def modifycmd
                    [
                        "groupmod",
                        self.class.xaddflag,
                        "'%s'" % @should,
                        @parent.name
                    ].join(" ")
                end
            end

            class GroupGID       < ObjectAddGroup
                @objectaddflag = "-g"
            end

            class ObjectAddUser < POSIX::POSIXState
                class << self
                    attr_accessor :extender
                end

                @subs = []
                def self.inherited(sub)
                    @subs << sub
                    mod = "Puppet::State::%s" %
                        sub.to_s.sub(/.+::/,'')
                    begin
                    modklass = eval(mod)
                    rescue NameError
                        raise Puppet::Error,
                            "Could not find extender module for %s" % sub.to_s
                    end
                    sub.include(modklass)

                    sub.extender = modklass
                end

                def self.substates
                    @subs
                end

                def addcmd
                    cmd = ["useradd"]
                    @parent.eachstate { |state|
                        # the value needs to be quoted, mostly because -c might
                        # have spaces in it
                        cmd << state.class.objectaddflag << "'%s'" % state.should
                    }

                    cmd.join(" ")
                end
                
                def deletecmd
                    ["userdel", @parent.name].join(" ")
                end

                def modifycmd
                cmd = [
                    "usermod",
                    self.class.objectaddflag,
                    "'%s'" % @should,
                    @parent.name
                ].join(" ")
                end
            end
            class UserUID       < ObjectAddUser
                @objectaddflag = "-u"
            end

            class UserGID       < ObjectAddUser
                @objectaddflag = "-g"
            end

            class UserComment   < ObjectAddUser
                @objectaddflag = "-d"
            end

            class UserHome      < ObjectAddUser
                @objectaddflag = "-d"
            end

            class UserShell     < ObjectAddUser
                @objectaddflag = "-s"
            end

            class UserLocked    < ObjectAddUser
            end

            class UserExpire    < ObjectAddUser
                @objectaddflag = "-e"
            end

            class UserInactive  < ObjectAddUser
                @objectaddflag = "-f"
            end
        end
    end
end
