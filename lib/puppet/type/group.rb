require 'etc'
require 'facter'
require 'puppet/property/keyvalue'
require 'puppet/property/list'
require 'puppet/parameter/boolean'

module Puppet
  Type.newtype(:group) do
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

      defaultto :present

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
          raise Puppet::DevError, _("GID cannot be deleted")
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
            self.fail _("Invalid GID %{gid}") % { gid: gid }
          end
        when Symbol
          unless gid == :absent
            self.devfail "Invalid GID #{gid}"
          end
        end

        return gid
      end
    end

    newproperty(:members, :parent => Puppet::Property::List, :required_features => :manages_members) do
      desc "The members of the group. For platforms or directory services where group
        membership is stored in the group objects, not the users. This parameter's
        behavior can be configured with `auth_membership`."

      validate do |value|
        unless value.is_a?(String)
          raise ArgumentError, _("The members property must be specified as either an array of strings, or as a single string consisting of a comma-separated list of members")
        end

        if value.is_a?(Integer) || value =~ /^\d+$/
          raise ArgumentError, _("User names must be provided, not UID numbers.")
        end

        if value.empty?
          raise ArgumentError, _("User names must not be empty. If you want to specify \"no users\" pass an empty array")
        end

        if provider.respond_to?(:member_valid?)
          return provider.member_valid?(value)
        end
      end

      def inclusive?
        @resource[:auth_membership]
      end

      def change_to_s(currentvalue, newvalue)
        newvalue = newvalue.split(",") if newvalue != :absent

        if provider.respond_to?(:members_to_s)
          # for Windows ADSI
          # de-dupe the "newvalue" when the sync event message is generated,
          # due to final retrieve called after the resource has been modified
          newvalue = provider.members_to_s(newvalue).split(',').uniq
        end

        super(currentvalue, newvalue)
      end

      # override Puppet::Property::List#retrieve
      def retrieve
        if provider.respond_to?(:members_to_s)
          # Windows ADSI members returns SIDs, but retrieve needs names
          # must return qualified names for SIDs for "is" value and puppet resource
          return provider.members_to_s(provider.members).split(',')
        end

        super
      end

      # The members property should also accept a comma separated
      # list of members (a String parameter) for backwards
      # compatibility. Unfortunately, the List property would treat
      # our comma separated list of members as a single-element Array.
      # This override of should= ensures that a comma separated list of
      # members is munged to an array of members, which is what we want.
      # Note that we cannot use `munge` because that will pass in each
      # array element instead of the entire array if the members property
      # is specified as an array of members, which would cause each member
      # to be munged into an array for that case. This is undesirable
      # behavior.
      def should=(values)
        super(values)

        if @should.length == 1 && @should.first.include?(delimiter)
          @should = @should.first.split(delimiter)
        end

        @should
      end

      def insync?(current)
        if provider.respond_to?(:members_insync?)
          return provider.members_insync?(current, @should)
        end

        super(current)
      end
    end

    newparam(:auth_membership, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc "Configures the behavior of the `members` parameter.

        * `false` (default) --- The provided list of group members is partial,
          and Puppet **ignores** any members that aren't listed there.
        * `true` --- The provided list of of group members is comprehensive, and
          Puppet **purges** any members that aren't listed there."
      defaultto false
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

    newparam(:allowdupe, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc "Whether to allow duplicate GIDs."

      defaultto false
    end

    newparam(:ia_load_module, :required_features => :manages_aix_lam) do
      desc "The name of the I&A module to use to manage this user"
    end

    newproperty(:attributes, :parent => Puppet::Property::KeyValue, :required_features => :manages_aix_lam) do
      desc "Specify group AIX attributes, as an array of `'key=value'` strings. This
        parameter's behavior can be configured with `attribute_membership`."

      self.log_only_changed_or_new_keys = true

      def membership
        :attribute_membership
      end

      def delimiter
        " "
      end
    end

    newparam(:attribute_membership) do
      desc "AIX only. Configures the behavior of the `attributes` parameter.

        * `minimum` (default) --- The provided list of attributes is partial, and Puppet
          **ignores** any attributes that aren't listed there.
        * `inclusive` --- The provided list of attributes is comprehensive, and
          Puppet **purges** any attributes that aren't listed there."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newparam(:system, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc "Whether the group is a system group with lower GID."

      defaultto false
    end

    newparam(:forcelocal, :boolean => true,
             :required_features => :libuser,
             :parent => Puppet::Parameter::Boolean) do
      desc "Forces the management of local accounts when accounts are also
            being managed by some other NSS"
      defaultto false
    end

    # This method has been exposed for puppet to manage users and groups of
    # files in its settings and should not be considered available outside of
    # puppet.
    #
    # (see Puppet::Settings#service_group_available?)
    #
    # @return [Boolean] if the group exists on the system
    # @api private
    def exists?
      provider.exists?
    end
  end
end
