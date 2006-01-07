require 'puppet'

module Puppet
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

            # Does the object already exist?
            def self.exists?(obj)
                if obj.getinfo
                    return true
                else
                    return false
                end
            end

            # The base state class for <object>add operations.
            class ObjectAddState < Puppet::State::NSSState
                class << self
                    # Determine the flag to pass to our command.
                    def objectaddflag
                        unless defined? @objectaddflag
                            # Else, return the first letter of the name.  I have to
                            # user a range here, else the character will show up
                            # as a number, rather than as a string, for some reason.
                            @objectaddflag = "-" + self.name.to_s[0,1]
                            Puppet.debug "Setting flag on %s to %s" %
                                [self.name, @objectaddflag]
                        end
                        return @objectaddflag
                    end

                    # Set the flag manually.
                    def setflag(value)
                        @objectaddflag = value
                    end
                end
            end

            # The state class for doing group operations using groupadd or whatever.
            # I could probably have abstracted the User and Group classes into
            # a single class, but eh, it just didn't seem worth it.
            class ObjectAddGroup < ObjectAddState
                class << self
                    # This is hackish, but hey, it works.
                    def finish
                        @allatonce = true
                    end
                end

                def addcmd
                    cmd = ["groupadd"]
                    if gid = @parent.should(:gid)
                        unless gid == :auto
                            cmd << self.class.objectaddflag << gid 
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
                        "'%s'" % self.should,
                        @parent.name
                    ].join(" ")
                end
            end

            # The class for adding users using 'adduser'.
            class ObjectAddUser < ObjectAddState
                class << self
                    # This is hackish, but hey, it works.
                    def finish
                        @allatonce = true
                        case self.name
                        when :home: setflag "-d"
                        end
                    end
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
                        "'%s'" % self.should,
                        @parent.name
                    ].join(" ")
                end
            end
        end
    end
end
