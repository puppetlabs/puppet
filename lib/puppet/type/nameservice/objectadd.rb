require 'puppet'

module Puppet
    class State
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

            def self.exists?(obj)
                if obj.getinfo
                    return true
                else
                    return false
                end
            end

            class ObjectAddGroup < POSIX::POSIXState
                def self.allatonce?
                    true
                end

                def addcmd
                    cmd = ["groupadd"]
                    if gid = @parent.should(:gid)
                        unless gid == :auto
                            cmd << "-g" << gid 
                        end
                    end
                    cmd << @parent.name

                    return cmd.join(" ")
                end

                def deletecmd
                    "groupdel %s" % @parent.name
                end

                def modifycmd
                    [
                        "groupmod",
                        self.class.objectaddflag,
                        "'%s'" % @should,
                        @parent.name
                    ].join(" ")
                end
            end

            class GroupGID       < ObjectAddGroup
                @objectaddflag = "-g"
                @autogen = true
            end

            class ObjectAddUser < POSIX::POSIXState
                def self.allatonce?
                    true
                end

                def addcmd
                    cmd = ["useradd"]
                    @parent.eachstate { |state|
                        # the value needs to be quoted, mostly because -c might
                        # have spaces in it
                        cmd << state.class.objectaddflag << "'%s'" % state.should
                    }
                    # stupid fedora
                    case Facter["distro"].value
                    when "Fedora", "RedHat":
                        cmd << "-M"
                    else
                    end
                    cmd << @parent.name

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
                @autogen = true
            end

            class UserGID       < ObjectAddUser
                @objectaddflag = "-g"
                @autogen = true
            end

            class UserComment   < ObjectAddUser
                @objectaddflag = "-c"
            end

            class UserHome      < ObjectAddUser
                @objectaddflag = "-d"
                @autogen = true
            end

            class UserShell     < ObjectAddUser
                @objectaddflag = "-s"
                @autogen = true
            end

            class UserLocked    < ObjectAddUser
            end

            class UserExpire    < ObjectAddUser
                @objectaddflag = "-e"
                @autogen = true
            end

            class UserInactive  < ObjectAddUser
                @objectaddflag = "-f"
                @autogen = true
            end
        end
    end
end
