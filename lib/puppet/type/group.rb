# Manage Unix groups.  This class is annoyingly complicated; There
# is some variety in whether systems use 'groupadd' or 'addgroup', but OS X
# significantly complicates the picture by using NetInfo.  Eventually we
# will also need to deal with systems that have their groups hosted elsewhere
# (e.g., in LDAP).  That will likely only be a problem for OS X, since it
# currently does not use the POSIX interfaces, since lookupd's cache screws
# things up.

require 'etc'
require 'facter'
require 'puppet/type/state'

module Puppet
    class State
        module GroupGID
            def self.doc
                "The group ID.  Must be specified numerically.  If not
                specified, a number will be picked, which can result in ID
                differences across systems and thus is not recommended.  The
                GID is picked according to local system standards."
            end

            def self.name
                :gid
            end

            def should=(gid)
                if gid.is_a?(String)
                    if gid =~ /^[0-9]+$/
                        gid = Integer(gid)
                    else
                        raise Puppet::Error, "Invalid GID %s" % gid
                    end
                end

                if gid.is_a?(Integer) and gid < 0
                    raise Puppet::Error, "GIDs must be positive"
                end

                Puppet.info "Setting gid to %s" % gid

                @should = gid
            end
        end
    end

    class Type
        class Group < Type
            statemodule = nil
            case Facter["operatingsystem"].value
            when "Darwin":
                statemodule = Puppet::NameService::NetInfo::NetInfoGroup
            else
                statemodule = Puppet::NameService::ObjectAdd::ObjectAddGroup
            end

            @states = statemodule.substates

            @name = :group
            @namevar = :name

            @parameters = [:name]

            @netinfodir = "groups"

            @paramdoc[:name] = "The group name.  While naming limitations vary by
                system, it is advisable to keep the name to the degenerate
                limitations, which is a maximum of 8 characters beginning with
                a letter."

            @doc = "Manage groups.  This type can only create groups.  Group
                membership must be managed on individual users."

            def exists?
                case @@extender
                when "NInfo":
                    cmd = "nidump -r /groups/%s /" % self.name
                    output = %x{#{cmd} 2>/dev/null}
                    if output == ""
                        return false
                    else
                        return true
                    end
                else
                    if self.getinfo
                        return true
                    else
                        return false
                    end
                end
            end

            def getinfo(refresh = false)
                if @groupinfo.nil? or refresh == true
                    begin
                        @groupinfo = Etc.getgrnam(self.name)
                    rescue ArgumentError => detail
                        @groupinfo = nil
                    end
                end

                @groupinfo
            end

            def initialize(hash)
                @groupinfo = nil
                super
            end

            def retrieve
                if self.exists?
                    super
                else
                    # the group does not exist

                    # unless we're in noop mode, we need to auto-pick a gid if
                    # there hasn't been one specified
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
                end
            end
        end
    end
end

# $Id$
