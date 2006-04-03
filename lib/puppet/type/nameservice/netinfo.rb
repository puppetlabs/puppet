# Manage NetInfo POSIX objects.  Probably only used on OS X, but I suppose
# it could be used elsewhere.

require 'puppet'
require 'puppet/type/nameservice/posix'

module Puppet
    module NameService
        module NetInfo
            # Verify that we've got all of the commands we need.
            def self.test
                system("which niutil > /dev/null 2>&1")

                if $? == 0
                    return true
                else
                    Puppet.err "Could not find niutil"
                    return false
                end

                system("which nireport > /dev/null 2>&1")

                if $? == 0
                    return true
                else
                    Puppet.err "Could not find nireport"
                    return false
                end
            end

            # Does the object already exist?
            def self.exists?(obj)
                cmd = "nidump -r /%s/%s /" %
                    [obj.class.netinfodir, obj[:name]]

                output = %x{#{cmd} 2>/dev/null}
                if output == ""
                    return false
                else
                    #Puppet.debug "%s exists: %s" % [obj.name, output]
                    return true
                end
            end

            # Attempt to flush the database, but this doesn't seem to work at all.
            def self.flush
                output = %x{lookupd -flushcache 2>&1}

                if $? != 0
                    Puppet.err "Could not flush lookupd cache: %s" % output
                end
            end

            # The state responsible for handling netinfo objects.  Because they
            # are all accessed using the exact same interface, we can just 
            # abstract the differents using a simple map where necessary
            # (the netinfokeymap).
            class NetInfoState < Puppet::State::NSSState
                # Similar to posixmethod, what key do we use to get data?  Defaults
                # to being the object name.
                def self.netinfokey
                    if defined? @netinfokey
                        return @netinfokey
                    else
                        return self.name
                    end
                end

                def self.setkey(key)
                    @netinfokey = key
                end

                def self.finish
                    @allatonce = false
                    case self.name
                    when :comment: setkey "realname"
                    when :uid:
                        noautogen
                    when :gid:
                        noautogen
                    end
                end

                # Retrieve the data, yo.
                def retrieve
                    NetInfo.flush
                    dir = @parent.class.netinfodir
                    cmd = ["nireport", "/", "/%s" % dir, "name"]

                    if key = self.class.netinfokey
                        cmd << key.to_s
                    else
                        raise Puppet::DevError,
                            "Could not find netinfokey for state %s" %
                            self.class.name
                    end
                    self.debug "Executing %s" % cmd.join(" ").inspect

                    %x{#{cmd.join(" ")} 2>&1}.split("\n").each { |line|
                        if line =~ /^(\w+)\s+(.+)$/
                            name = $1
                            value = $2.sub(/\s+$/, '')

                            if name == @parent[:name]
                                if value =~ /^[-0-9]+$/
                                    @is = Integer(value)
                                else
                                    @is = value
                                end
                            end
                        else
                            raise Puppet::DevError, "Could not match %s" % line
                        end
                    }

                    unless defined? @is
                        @is = :absent
                    end
                end

                # The list of all groups the user is a member of.  Different
                # user mgmt systems will need to override this method.
                def grouplist
                    groups = []

                    user = @parent[:name]
                    # Retrieve them all from netinfo
                    open("| nireport / /groups name users") do |file|
                        file.each do |line|
                            name, members = line.split(/\s+/)
                            next unless members
                            next if members =~ /NoValue/
                            members = members.split(",")

                            if members.include? user
                                groups << name
                            end
                        end
                    end

                    groups
                end

                # This is really lame.  We have to iterate over each
                # of the groups and add us to them.
                def setgrouplist(groups)
                    # Get just the groups we need to modify
                    diff = groups - @is

                    data = {}
                    open("| nireport / /groups name users") do |file|
                        file.each do |line|
                            name, members = line.split(/\s+/)

                            if members.nil? or members =~ /NoValue/
                                data[name] = []
                            else
                                # Add each diff group's current members
                                data[name] = members.split(/,/)
                            end
                        end
                    end

                    user = @parent[:name]
                    data.each do |name, members|
                        if members.include? user and groups.include? name
                            # I'm in the group and should be
                            next
                        elsif members.include? user
                            # I'm in the group and shouldn't be
                            setuserlist(name, members - [user])
                        elsif groups.include? name
                            # I'm not in the group and should be
                            setuserlist(name, members + [user])
                        else
                            # I'm not in the group and shouldn't be
                            next
                        end
                    end
                end

                def setuserlist(group, list)
                    cmd = "niutil -createprop / /groups/%s users %s" %
                        [group, list.join(",")]
                    output = %x{#{cmd}}
                end

                # How to add an object.
                def addcmd
                    creatorcmd("-create")
                end

                def creatorcmd(arg)
                    cmd = ["niutil"]
                    cmd << arg

                    cmd << "/" << "/%s/%s" %
                        [@parent.class.netinfodir, @parent[:name]]

                    #if arg == "-create"
                    #    return [cmd.join(" "), self.modifycmd].join(";")
                    #else
                        return cmd.join(" ")
                    #end
                end

                def deletecmd
                    creatorcmd("-destroy")
                end

                def modifycmd
                    cmd = ["niutil"]

                    cmd << "-createprop" << "/" << "/%s/%s" %
                        [@parent.class.netinfodir, @parent[:name]]

                    if key = self.class.netinfokey
                        cmd << key << "'%s'" % self.should
                    else
                        raise Puppet::DevError,
                            "Could not find netinfokey for state %s" %
                            self.class.name
                    end
                    cmd.join(" ")
                end
            end
        end
    end
end
