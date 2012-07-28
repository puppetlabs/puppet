require 'etc'
require 'facter'
require 'puppet/property/list'
require 'puppet/property/ordered_list'
require 'puppet/property/keyvalue'

module Puppet
  newtype(:user) do
    @doc = "Manage users.  This type is mostly built to manage system
      users, so it is lacking some features useful for managing normal
      users.

      This resource type uses the prescribed native tools for creating
      groups and generally uses POSIX APIs for retrieving information
      about them.  It does not directly modify `/etc/passwd` or anything.

      **Autorequires:** If Puppet is managing the user's primary group (as
      provided in the `gid` attribute), the user resource will autorequire
      that group. If Puppet is managing any role accounts corresponding to the
      user's roles, the user resource will autorequire those role accounts."

    feature :allows_duplicates,
      "The provider supports duplicate users with the same UID."

    feature :manages_homedir,
      "The provider can create and remove home directories."

    feature :manages_passwords,
      "The provider can modify user passwords, by accepting a password
      hash."

    feature :manages_password_age,
      "The provider can set age requirements and restrictions for
      passwords."

    feature :manages_solaris_rbac,
      "The provider can manage roles and normal users"

    feature :manages_expiry,
      "The provider can manage the expiry date for a user."

   feature :system_users,
     "The provider allows you to create system users with lower UIDs."

    feature :manages_aix_lam,
      "The provider can manage AIX Loadable Authentication Module (LAM) system."

    newproperty(:ensure, :parent => Puppet::Property::Ensure) do
      newvalue(:present, :event => :user_created) do
        provider.create
      end

      newvalue(:absent, :event => :user_removed) do
        provider.delete
      end

      newvalue(:role, :event => :role_created, :required_features => :manages_solaris_rbac) do
        provider.create_role
      end

      desc "The basic state that the object should be in."

      # If they're talking about the thing at all, they generally want to
      # say it should exist.
      defaultto do
        if @resource.managed?
          :present
        else
          nil
        end
      end

      def retrieve
        if provider.exists?
          if provider.respond_to?(:is_role?) and provider.is_role?
            return :role
          else
            return :present
          end
        else
          return :absent
        end
      end
    end

    newproperty(:home) do
      desc "The home directory of the user.  The directory must be created
        separately and is not currently checked for existence."
    end

    newproperty(:uid) do
      desc "The user ID; must be specified numerically. If no user ID is
        specified when creating a new user, then one will be chosen
        automatically. This will likely result in the same user having
        different UIDs on different systems, which is not recommended. This is
        especially noteworthy when managing the same user on both Darwin and
        other platforms, since Puppet does UID generation on Darwin, but
        the underlying tools do so on other platforms.

        On Windows, this property is read-only and will return the user's
        security identifier (SID)."

      munge do |value|
        case value
        when String
          if value =~ /^[-0-9]+$/
            value = Integer(value)
          end
        end

        return value
      end
    end

    newproperty(:gid) do
      desc "The user's primary group.  Can be specified numerically or by name.

        Note that users on Windows systems do not have a primary group; manage groups
        with the `groups` attribute instead."

      munge do |value|
        if value.is_a?(String) and value =~ /^[-0-9]+$/
          Integer(value)
        else
          value
        end
      end

      def insync?(is)
        # We know the 'is' is a number, so we need to convert the 'should' to a number,
        # too.
        @should.each do |value|
          return true if number = Puppet::Util.gid(value) and is == number
        end

        false
      end

      def sync
        found = false
        @should.each do |value|
          if number = Puppet::Util.gid(value)
            provider.gid = number
            found = true
            break
          end
        end

        fail "Could not find group(s) #{@should.join(",")}" unless found

        # Use the default event.
      end
    end

    newproperty(:comment) do
      desc "A description of the user.  Generally the user's full name."
    end

    newproperty(:shell) do
      desc "The user's login shell.  The shell must exist and be
        executable.

        This attribute cannot be managed on Windows systems."
    end

    newproperty(:password, :required_features => :manages_passwords) do
      desc %q{The user's password, in whatever encrypted format the local
        system requires.

        * Most modern Unix-like systems use salted SHA1 password hashes. You can use
          Puppet's built-in `sha1` function to generate a hash from a password.
        * Mac OS X 10.5 and 10.6 also use salted SHA1 hashes.
        * Mac OS X 10.7 (Lion) uses salted SHA512 hashes. The Puppet Labs [stdlib][]
          module contains a `str2saltedsha512` function which can generate password
          hashes for Lion.
        * Windows passwords can only be managed in cleartext, as there is no Windows API
          for setting the password hash.

        [stdlib]: https://github.com/puppetlabs/puppetlabs-stdlib/

        Be sure to enclose any value that includes a dollar sign ($) in single
        quotes (') to avoid accidental variable interpolation.}

      validate do |value|
        raise ArgumentError, "Passwords cannot include ':'" if value.is_a?(String) and value.include?(":")
      end

      def change_to_s(currentvalue, newvalue)
        if currentvalue == :absent
          return "created password"
        else
          return "changed password"
        end
      end

      def is_to_s( currentvalue )
        return '[old password hash redacted]'
      end
      def should_to_s( newvalue )
        return '[new password hash redacted]'
      end

    end

    newproperty(:password_min_age, :required_features => :manages_password_age) do
      desc "The minimum number of days a password must be used before it may be changed."

      munge do |value|
        case value
        when String
          Integer(value)
        else
          value
        end
      end

      validate do |value|
        if value.to_s !~ /^-?\d+$/
          raise ArgumentError, "Password minimum age must be provided as a number."
        end
      end
    end

    newproperty(:password_max_age, :required_features => :manages_password_age) do
      desc "The maximum number of days a password may be used before it must be changed."

      munge do |value|
        case value
        when String
          Integer(value)
        else
          value
        end
      end

      validate do |value|
        if value.to_s !~ /^-?\d+$/
          raise ArgumentError, "Password maximum age must be provided as a number."
        end
      end
    end

    newproperty(:groups, :parent => Puppet::Property::List) do
      desc "The groups to which the user belongs.  The primary group should
        not be listed, and groups should be identified by name rather than by
        GID.  Multiple groups should be specified as an array."

      validate do |value|
        if value =~ /^\d+$/
          raise ArgumentError, "Group names must be provided, not GID numbers."
        end
        raise ArgumentError, "Group names must be provided as an array, not a comma-separated list." if value.include?(",")
        raise ArgumentError, "Group names must not be empty. If you want to specify \"no groups\" pass an empty array" if value.empty?
      end
    end

    newparam(:name) do
      desc "The user name. While naming limitations vary by operating system,
        it is advisable to restrict names to the lowest common denominator,
        which is a maximum of 8 characters beginning with a letter.

        Note that Puppet considers user names to be case-sensitive, regardless
        of the platform's own rules; be sure to always use the same case when
        referring to a given user."
      isnamevar
    end

    newparam(:membership) do
      desc "Whether specified groups should be considered the **complete list**
        (`inclusive`) or the **minimum list** (`minimum`) of groups to which
        the user belongs. Defaults to `minimum`."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newparam(:system, :boolean => true) do
      desc "Whether the user is a system user, according to the OS's criteria;
      on most platforms, a UID less than or equal to 500 indicates a system
      user. Defaults to `false`."

      newvalues(:true, :false)

      defaultto false
    end

    newparam(:allowdupe, :boolean => true) do
      desc "Whether to allow duplicate UIDs. Defaults to `false`."

      newvalues(:true, :false)

      defaultto false
    end

    newparam(:managehome, :boolean => true) do
      desc "Whether to manage the home directory when managing the user.
        Defaults to `false`."

      newvalues(:true, :false)

      defaultto false

      validate do |val|
        if val.to_s == "true"
          raise ArgumentError, "User provider #{provider.class.name} can not manage home directories" unless provider.class.manages_homedir?
        end
      end
    end

    newproperty(:expiry, :required_features => :manages_expiry) do
      desc "The expiry date for this user. Must be provided in
           a zero-padded YYYY-MM-DD format --- e.g. 2010-02-19."

      validate do |value|
        if value !~ /^\d{4}-\d{2}-\d{2}$/
          raise ArgumentError, "Expiry dates must be YYYY-MM-DD"
        end
      end
    end

    # Autorequire the group, if it's around
    autorequire(:group) do
      autos = []

      if obj = @parameters[:gid] and groups = obj.shouldorig
        groups = groups.collect { |group|
          if group =~ /^\d+$/
            Integer(group)
          else
            group
          end
        }
        groups.each { |group|
          case group
          when Integer
            if resource = catalog.resources.find { |r| r.is_a?(Puppet::Type.type(:group)) and r.should(:gid) == group }
              autos << resource
            end
          else
            autos << group
          end
        }
      end

      if obj = @parameters[:groups] and groups = obj.should
        autos += groups.split(",")
      end

      autos
    end

    # Provide an external hook.  Yay breaking out of APIs.
    def exists?
      provider.exists?
    end

    def retrieve
      absent = false
      properties.inject({}) { |prophash, property|
        current_value = :absent

        if absent
          prophash[property] = :absent
        else
          current_value = property.retrieve
          prophash[property] = current_value
        end

        if property.name == :ensure and current_value == :absent
          absent = true
        end
        prophash
      }
    end

    newproperty(:roles, :parent => Puppet::Property::List, :required_features => :manages_solaris_rbac) do
      desc "The roles the user has.  Multiple roles should be
        specified as an array."

      def membership
        :role_membership
      end

      validate do |value|
        if value =~ /^\d+$/
          raise ArgumentError, "Role names must be provided, not numbers"
        end
        raise ArgumentError, "Role names must be provided as an array, not a comma-separated list" if value.include?(",")
      end
    end

    #autorequire the roles that the user has
    autorequire(:user) do
      reqs = []

      if roles_property = @parameters[:roles] and roles = roles_property.should
        reqs += roles.split(',')
      end

      reqs
    end

    newparam(:role_membership) do
      desc "Whether specified roles should be considered the **complete list**
        (`inclusive`) or the **minimum list** (`minimum`) of roles the user
        has. Defaults to `minimum`."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newproperty(:auths, :parent => Puppet::Property::List, :required_features => :manages_solaris_rbac) do
      desc "The auths the user has.  Multiple auths should be
        specified as an array."

      def membership
        :auth_membership
      end

      validate do |value|
        if value =~ /^\d+$/
          raise ArgumentError, "Auth names must be provided, not numbers"
        end
        raise ArgumentError, "Auth names must be provided as an array, not a comma-separated list" if value.include?(",")
      end
    end

    newparam(:auth_membership) do
      desc "Whether specified auths should be considered the **complete list**
        (`inclusive`) or the **minimum list** (`minimum`) of auths the user
        has. Defaults to `minimum`."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newproperty(:profiles, :parent => Puppet::Property::OrderedList, :required_features => :manages_solaris_rbac) do
      desc "The profiles the user has.  Multiple profiles should be
        specified as an array."

      def membership
        :profile_membership
      end

      validate do |value|
        if value =~ /^\d+$/
          raise ArgumentError, "Profile names must be provided, not numbers"
        end
        raise ArgumentError, "Profile names must be provided as an array, not a comma-separated list" if value.include?(",")
      end
    end

    newparam(:profile_membership) do
      desc "Whether specified roles should be treated as the **complete list**
        (`inclusive`) or the **minimum list** (`minimum`) of roles
        of which the user is a member. Defaults to `minimum`."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newproperty(:keys, :parent => Puppet::Property::KeyValue, :required_features => :manages_solaris_rbac) do
      desc "Specify user attributes in an array of key = value pairs."

      def membership
        :key_membership
      end

      validate do |value|
        raise ArgumentError, "Key/value pairs must be separated by an =" unless value.include?("=")
      end
    end

    newparam(:key_membership) do
      desc "Whether specified key/value pairs should be considered the
        **complete list** (`inclusive`) or the **minimum list** (`minimum`) of
        the user's attributes. Defaults to `minimum`."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newproperty(:project, :required_features => :manages_solaris_rbac) do
      desc "The name of the project associated with a user."
    end

    newparam(:ia_load_module, :required_features => :manages_aix_lam) do
      desc "The name of the I&A module to use to manage this user."
    end

    newproperty(:attributes, :parent => Puppet::Property::KeyValue, :required_features => :manages_aix_lam) do
      desc "Specify AIX attributes for the user in an array of attribute = value pairs."

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
      desc "Whether specified attribute value pairs should be treated as the
        **complete list** (`inclusive`) or the **minimum list** (`minimum`) of
        attribute/value pairs for the user. Defaults to `minimum`."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newproperty(:salt) do
      desc "This is the 32 byte salt used to generate the PBKDF2 password used in
            OS X"
    end

    newproperty(:iterations) do
      desc "This is the number of iterations of a chained computation of the
            password hash (http://en.wikipedia.org/wiki/PBKDF2).  This parameter
            is used in OS X"

      munge do |value|
        if value.is_a?(String) and value =~/^[-0-9]+$/
          Integer(value)
        else
          value
        end
      end
    end
  end
end
