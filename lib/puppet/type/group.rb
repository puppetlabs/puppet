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
require 'puppet/type/nameservice'

module Puppet
    newtype(:group, Puppet::Type::NSSType) do
        @doc = "Manage groups.  This type can only create groups.  Group
            membership must be managed on individual users.  This element type
            uses the prescribed native tools for creating groups and generally
            uses POSIX APIs for retrieving information about them.  It does
            not directly modify /etc/group or anything.
            
            For most platforms, the tools used are ``groupadd`` and its ilk;
            for Mac OS X, NetInfo is used.  This is currently unconfigurable,
            but if you desperately need it to be so, please contact us."

        case Facter["operatingsystem"].value
        when "Darwin":
            @parentstate = Puppet::NameService::NetInfo::NetInfoState
            @parentmodule = Puppet::NameService::NetInfo
        when "FreeBSD":
            @parentstate = Puppet::NameService::PW::PWGroup
            @parentmodule = Puppet::NameService::PW
        else
            @parentstate = Puppet::NameService::ObjectAdd::ObjectAddGroup
            @parentmodule = Puppet::NameService::ObjectAdd
        end

        newstate(:ensure, @parentstate) do
            newvalue(:present) do
                self.syncname(:present)
            end

            newvalue(:absent) do
                self.syncname(:absent)
            end

            desc "The basic state that the object should be in."

            # If they're talking about the thing at all, they generally want to
            # say it should exist.
            #defaultto :present
            defaultto do
                if @parent.managed?
                    :present
                else
                    nil
                end
            end

            def change_to_s
                begin
                    if @is == :absent
                        return "created"
                    elsif self.should == :absent
                        return "removed"
                    else
                        return "%s changed '%s' to '%s'" %
                            [self.name, self.is_to_s, self.should_to_s]
                    end
                rescue Puppet::Error, Puppet::DevError
                    raise
                rescue => detail
                    raise Puppet::DevError,
                        "Could not convert change %s to string: %s" %
                        [self.name, detail]
                end
            end

            def retrieve
                if @parent.exists?
                    @is = :present
                else
                    @is = :absent
                end
            end

            # The default 'sync' method only selects among a list of registered
            # values.
            def sync
                if self.insync?
                    self.info "already in sync"
                    return nil
                #else
                    #self.info "%s vs %s" % [self.is.inspect, self.should.inspect]
                end
                unless self.class.values
                    self.devfail "No values defined for %s" %
                        self.class.name
                end

                # Set ourselves to whatever our should value is.
                self.set
            end

        end

        newstate(:gid, @parentstate) do
            desc "The group ID.  Must be specified numerically.  If not
                specified, a number will be picked, which can result in ID
                differences across systems and thus is not recommended.  The
                GID is picked according to local system standards."

            def autogen
                highest = 0
                Etc.group { |group|
                    if group.gid > highest
                        unless group.gid > 65000
                            highest = group.gid
                        end
                    end
                }

                return highest + 1
            end

            munge do |gid|
                case gid
                when String
                    if gid =~ /^[-0-9]+$/
                        gid = Integer(gid)
                    else
                        self.fail "Invalid GID %s" % gid
                    end
                when Symbol
                    unless gid == :auto or gid == :absent
                        self.devfail "Invalid GID %s" % gid
                    end
                    if gid == :auto
                        unless self.class.autogen?
                            gid = autogen()
                            @parent.log "autogenerated value as %s" % gid
                        end
                    end
                end

                self.info "Setting gid to %s" % gid

                return gid
            end
        end

        class << self
            attr_accessor :netinfodir
        end

        @netinfodir = "groups"

        newparam(:name) do
            desc "The group name.  While naming limitations vary by
                system, it is advisable to keep the name to the degenerate
                limitations, which is a maximum of 8 characters beginning with
                a letter."

            isnamevar
        end

        def exists?
            self.class.parentmodule.exists?(self)
        end

        def getinfo(refresh = false)
            if @groupinfo.nil? or refresh == true
                begin
                    @groupinfo = Etc.getgrnam(self[:name])
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
                unless @states.include?(:gid)
                    self[:gid] = :auto
                end

                @states.each { |name, state|
                    state.is = :absent
                }

                return
            end
        end
    end
end

# $Id$
