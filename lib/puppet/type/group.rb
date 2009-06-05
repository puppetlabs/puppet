
require 'etc'
require 'facter'

module Puppet
    newtype(:group) do
        @doc = "Manage groups. On most platforms this can only create groups.
            Group membership must be managed on individual users.

            On some platforms such as OS X, group membership is managed as an
            attribute of the group, not the user record. Providers must have
            the feature 'manages_members' to manage the 'members' property of
            a group record."

        feature :manages_members,
            "For directories where membership is an attribute of groups not users."

        ensurable do
            desc "Create or remove the group."

            newvalue(:present) do
                provider.create

                :group_created
            end

            newvalue(:absent) do
                provider.delete

                :group_removed
            end
        end

        newproperty(:gid) do
            desc "The group ID.  Must be specified numerically.  If not
                specified, a number will be picked, which can result in ID
                differences across systems and thus is not recommended.  The
                GID is picked according to local system standards."

            def retrieve
                return provider.gid
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

        newproperty(:members, :array_matching => :all, :required_features => :manages_members) do
            desc "The members of the group. For directory services where group
            membership is stored in the group objects, not the users."

            def change_to_s(currentvalue, newvalue)
                currentvalue = currentvalue.join(",") if currentvalue != :absent
                newvalue = newvalue.join(",")
                super(currentvalue, newvalue)
            end
        end

        newparam(:auth_membership) do
            desc "whether the provider is authoritative for group membership."
            defaultto true
        end

        newparam(:name) do
            desc "The group name.  While naming limitations vary by
                system, it is advisable to keep the name to the degenerate
                limitations, which is a maximum of 8 characters beginning with
                a letter."
            isnamevar
        end

        newparam(:allowdupe, :boolean => true) do
            desc "Whether to allow duplicate GIDs.  This option does not work on
                FreeBSD (contract to the ``pw`` man page)."

            newvalues(:true, :false)

            defaultto false
        end
    end
end

