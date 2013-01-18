require 'etc'
require 'facter'
require 'puppet/property/keyvalue'

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

    feature :manages_aix_lam,
      "The provider can manage AIX Loadable Authentication Module (LAM) system."

    feature :system_groups,
      "The provider allows you to create system groups with lower GIDs."

    feature :libuser,
      "Allows local groups to be managed on systems that also use some other
       remote NSS method of managing accounts."

    ensurable do
      desc "Create or remove the group."

      newvalue(:present) do
        provider.create
      end

      newvalue(:absent) do
        provider.delete
      end
    end

    newproperty(:gid) do
      desc "The group ID.  Must be specified numerically.  If no group ID is
        specified when creating a new group, then one will be chosen
        automatically according to local system standards. This will likely
        result in the same group having different GIDs on different systems,
        which is not recommended.

        On Windows, this property is read-only and will return the group's security
        identifier (SID)."

      def retrieve
        provider.gid
      end

      def sync
        if self.should == :absent
          raise Puppet::DevError, "GID cannot be deleted"
        else
          provider.gid = self.should
        end
      end

      munge do |gid|
        case gid
        when String
          if gid =~ /^[-0-9]+$/
            gid = Integer(gid)
          else
            self.fail "Invalid GID #{gid}"
          end
        when Symbol
          unless gid == :absent
            self.devfail "Invalid GID #{gid}"
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
      desc "The group name. While naming limitations vary by operating system,
        it is advisable to restrict names to the lowest common denominator,
        which is a maximum of 8 characters beginning with a letter.

        Note that Puppet considers group names to be case-sensitive, regardless
        of the platform's own rules; be sure to always use the same case when
        referring to a given group."
      isnamevar
    end

    newparam(:allowdupe, :boolean => true) do
      desc "Whether to allow duplicate GIDs. Defaults to `false`."

      newvalues(:true, :false)

      defaultto false
    end

    newparam(:ia_load_module, :required_features => :manages_aix_lam) do
      desc "The name of the I&A module to use to manage this user"
    end

    newproperty(:attributes, :parent => Puppet::Property::KeyValue, :required_features => :manages_aix_lam) do
      desc "Specify group AIX attributes in an array of `key=value` pairs."

      def membership
        :attribute_membership
      end

      def delimiter
        " "
      end

      validate do |value|
        raise ArgumentError, "Attributes value pairs must be separated by an =" unless value.include?("=")
      end
    end

    newparam(:attribute_membership) do
      desc "Whether specified attribute value pairs should be treated as the only attributes
        of the user or whether they should merely
        be treated as the minimum list."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newparam(:system, :boolean => true) do
      desc "Whether the group is a system group with lower GID."

      newvalues(:true, :false)

      defaultto false
    end

    newparam(:forcelocal, :boolean => true, :required_features => :libuser ) do
      desc "Forces the mangement of local accounts when accounts are also
            being managed by some other NSS"
      newvalues(:true, :false)
      defaultto false
    end

    # This method has been exposed for puppet to manage users and groups of
    # files in its settings and should not be considered available outside of
    # puppet.
    #
    # (see Puppet::Settings#service_group_available?)
    #
    # @returns [Boolean] if the group exists on the system
    # @api private
    def exists?
      provider.exists?
    end
  end
end
