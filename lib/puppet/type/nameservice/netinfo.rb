# Manage NetInfo POSIX objects.  Probably only used on OS X, but I suppose
# it could be used elsewhere.

require 'puppet'
require 'puppet/type/nameservice/posix'

module Puppet
    class Type
        # Return the NetInfo directory in which a given object type is stored.
        # Defaults to the type's name if @netinfodir is unset.
        def self.netinfodir
            if defined? @netinfodir and @netinfodir
                return @netinfodir
            else
                return @name
            end
        end
    end

    module NameService
        module NetInfo
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

            def self.exists?(obj)
                cmd = "nidump -r /%s/%s /" %
                    [obj.class.netinfodir, obj.name]

                output = %x{#{cmd} 2>/dev/null}
                if output == ""
                    return false
                else
                    return true
                end
            end

            def self.flush
                output = %x{lookupd -flushcache 2>&1}

                if $? != 0
                    Puppet.err "Could not flush lookupd cache: %s" % output
                end
            end

            class NetInfoState < POSIX::POSIXState
                def self.netinfokey
                    if defined? @netinfokey and @netinfokey
                        return @netinfokey
                    else
                        return @name
                    end
                end

                def retrieve
                    dir = @parent.class.netinfodir
                    cmd = ["nireport", "/" "/%s" % dir, "name"]

                    if key = self.class.netinfokey
                        cmd << key.to_s
                    else
                        raise Puppet::DevError,
                            "Could not find netinfokey for state %s" %
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

                def addcmd
                    creatorcmd("-create")
                end

                def creatorcmd(arg)
                    cmd = ["niutil"]
                    cmd << arg

                    cmd << "/" << "/%s/%s" %
                        [@parent.class.netinfodir, @parent.name]

                    cmd.join(" ")
                end

                def deletecmd
                    creatorcmd("-destroy")
                end

                def modifycmd
                    cmd = ["niutil"]

                    cmd << "-createprop" << "/" << "/%s/%s" %
                        [@parent.class.netinfodir, @parent.name]

                    if key = self.class.netinfokey
                        cmd << key << "'%s'" % @should
                    else
                        raise Puppet::DevError,
                            "Could not find netinfokey for state %s" %
                            self.class.name
                    end
                    cmd.join(" ")
                end
            end

            class GroupGID < NetInfoState; end
        end
    end
end
