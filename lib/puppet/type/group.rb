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
    newtype(:group) do
        @doc = "Manage groups.  This type can only create groups.  Group
            membership must be managed on individual users.  This element type
            uses the prescribed native tools for creating groups and generally
            uses POSIX APIs for retrieving information about them.  It does
            not directly modify /etc/group or anything.
            
            For most platforms, the tools used are ``groupadd`` and its ilk;
            for Mac OS X, NetInfo is used.  This is currently unconfigurable,
            but if you desperately need it to be so, please contact us."

        newstate(:ensure) do
            desc "The basic state that the object should be in."

            newvalue(:present) do
                provider.create

                :group_created
            end

            newvalue(:absent) do
                provider.delete

                :group_removed
            end

            # If they're talking about the thing at all, they generally want to
            # say it should exist.
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
                if provider.exists?
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
                self.set(self.should)
            end

        end

        newstate(:gid) do
            desc "The group ID.  Must be specified numerically.  If not
                specified, a number will be picked, which can result in ID
                differences across systems and thus is not recommended.  The
                GID is picked according to local system standards."

            def retrieve
                @is = provider.gid
            end

            def sync
                if self.should == :absent
                    raise Puppet::DevError, "GID cannot be deleted"
                else
                    provider.gid = self.should
                    :group_modified
                end
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
                    unless gid == :absent
                        self.devfail "Invalid GID %s" % gid
                    end
                end

                return gid
            end
        end

        newparam(:name) do
            desc "The group name.  While naming limitations vary by
                system, it is advisable to keep the name to the degenerate
                limitations, which is a maximum of 8 characters beginning with
                a letter."

            isnamevar
        end

        newparam(:allowdupe) do
            desc "Whether to allow duplicate GIDs.  This option does not work on
                FreeBSD (contract to the ``pw`` man page)."
                
            newvalues(:true, :false)

            defaultto false
        end

        def self.list_by_name
            users = []
            defaultprovider.listbyname do |user|
                users << user
            end
            return users
        end

        def self.list
            defaultprovider.list

            self.collect do |user|
                user
            end
        end

        def retrieve
            if self.provider and @provider.exists?
                super
            else
                # the group does not exist
                #unless @states.include?(:gid)
                #    self[:gid] = :auto
                #end

                @states.each { |name, state|
                    state.is = :absent
                }

                return
            end
        end
    end
end

# $Id$
