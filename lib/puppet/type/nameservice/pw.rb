require 'puppet'
require 'puppet/type/nameservice/objectadd'

module Puppet
    module NameService
        module PW
            # Verify that we've got the commands necessary to manage flat files.
            def self.test
                system("which pw > /dev/null 2>&1")

                if $? == 0
                    return true
                else
                    Puppet.err "Could not find pw"
                    return false
                end
            end

            # Does the object already exist?
            def self.exists?(obj)
                if obj.getinfo
                    return true
                else
                    return false
                end
            end

            # The state class for doing group operations using groupadd or whatever.
            # I could probably have abstracted the User and Group classes into
            # a single class, but eh, it just didn't seem worth it.
            class PWGroup < ObjectAdd::ObjectAddGroup
                def addcmd
                    cmd = ["pw", "groupadd", @parent[:name]]
                    if gid = @parent.should(:gid)
                        unless gid == :auto
                            cmd << self.class.objectaddflag << gid 
                        end
                    end

                    return cmd.join(" ")
                end

                def deletecmd
                    "pw groupdel %s" % @parent[:name]
                end

                def modifycmd
                    [
                        "pw",
                        "groupmod",
                        @parent[:name],
                        self.class.objectaddflag,
                        "'%s'" % self.should
                    ].join(" ")
                end
            end

            # The class for adding users using 'adduser'.
            class PWUser < ObjectAdd::ObjectAddUser
                def addcmd
                    cmd = ["pw", "useradd", @parent[:name], "-w", "no"]
                    @parent.eachstate { |state|
                        next if state.name == :ensure
                        # the value needs to be quoted, mostly because -c might
                        # have spaces in it
                        cmd << state.class.objectaddflag << "'%s'" % state.should
                    }
                    # stupid fedora
                    case Facter["operatingsystem"].value
                    when "Fedora", "RedHat":
                        cmd << "-M"
                    end

                    cmd.join(" ")
                end
                
                def deletecmd
                    ["pw", "userdel", @parent[:name]].join(" ")
                end

                def modifycmd
                    cmd = [
                        "pw",
                        "usermod",
                        @parent[:name],
                        "-w", "no",
                        self.class.objectaddflag,
                        "'%s'" % self.should
                    ].join(" ")
                end
            end
        end
    end
end
