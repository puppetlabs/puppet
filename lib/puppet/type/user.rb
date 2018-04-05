require 'etc'
require 'facter'
require 'puppet/parameter/boolean'
require 'puppet/property/list'
require 'puppet/property/ordered_list'
require 'puppet/property/keyvalue'

module Puppet
  Type.newtype(:user) do
    @doc = "Manage users.  This type is mostly built to manage system
      users, so it is lacking some features useful for managing normal
      users.

      This resource type uses the prescribed native tools for creating
      groups and generally uses POSIX APIs for retrieving information
      about them.  It does not directly modify `/etc/passwd` or anything.

      **Autorequires:** If Puppet is managing the user's primary group (as
      provided in the `gid` attribute) or any group listed in the `groups`
      attribute then the user resource will autorequire that group. If Puppet
      is managing any role accounts corresponding to the user's roles, the
      user resource will autorequire those role accounts."

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

    feature :manages_password_salt,
      "The provider can set a password salt. This is for providers that
       implement PBKDF2 passwords with salt properties."

    feature :manages_solaris_rbac,
      "The provider can manage roles and normal users"

    feature :manages_expiry,
      "The provider can manage the expiry date for a user."

   feature :system_users,
     "The provider allows you to create system users with lower UIDs."

    feature :manages_aix_lam,
      "The provider can manage AIX Loadable Authentication Module (LAM) system."

    feature :libuser,
      "Allows local users to be managed on systems that also use some other
       remote NSS method of managing accounts."

    feature :manages_shell,
      "The provider allows for setting shell and validates if possible"

    feature :manages_loginclass,
      "The provider can manage the login class for a user."

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

        This attribute is not supported on Windows systems; use the `groups`
        attribute instead. (On Windows, designating a primary group is only
        meaningful for domain accounts, which Puppet does not currently manage.)"

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

        fail _("Could not find group(s) %{groups}") % { groups: @should.join(",") } unless found

        # Use the default event.
      end
    end

    newproperty(:comment) do
      desc "A description of the user.  Generally the user's full name."
      def insync?(is)
        # nameservice provider requires special attention to encoding
        # Overrides Puppet::Property#insync?
        if !@should.empty? && provider.respond_to?(:comments_insync?)
          return provider.comments_insync?(is, @should)
        end
        super(is)
      end

      # In the case that our comments have incompatible encodings, set external
      # encoding to support concatenation for display.
      # overrides Puppet::Property#change_to_s
      def change_to_s(currentvalue, newvalue)
        if newvalue.respond_to?(:force_encoding) && !Encoding.compatible?(currentvalue, newvalue)
          return super(currentvalue, newvalue.dup.force_encoding(currentvalue.encoding))
        end
        super(currentvalue, newvalue)
      end
    end

    newproperty(:shell, :required_features => :manages_shell) do
      desc "The user's login shell.  The shell must exist and be
        executable.

        This attribute cannot be managed on Windows systems."
    end

    newproperty(:password, :required_features => :manages_passwords) do
      desc %q{The user's password, in whatever encrypted format the local system
        requires. Consult your operating system's documentation for acceptable password
        encryption formats and requirements.

        * Mac OS X 10.5 and 10.6, and some older Linux distributions, use salted SHA1
          hashes. You can use Puppet's built-in `sha1` function to generate a salted SHA1
          hash from a password.
        * Mac OS X 10.7 (Lion), and many recent Linux distributions, use salted SHA512
          hashes. The Puppet Labs [stdlib][] module contains a `str2saltedsha512` function
          which can generate password hashes for these operating systems.
        * OS X 10.8 and higher use salted SHA512 PBKDF2 hashes. When managing passwords
          on these systems, the `salt` and `iterations` attributes need to be specified as
          well as the password.
        * Windows passwords can be managed only in cleartext, because there is no Windows
          API for setting the password hash.

        [stdlib]: https://github.com/puppetlabs/puppetlabs-stdlib/

        Enclose any value that includes a dollar sign ($) in single quotes (') to avoid
        accidental variable interpolation.

        To redact passwords from reports to PuppetDB, use the `Sensitive` data type. For
        example, this resource protects the password:

        ```puppet
        user { 'foo':
          ensure   => present,
          password => Sensitive("my secret password")
        }
        ```

        This results in the password being redacted from the report, as in the
        `previous_value`, `desired_value`, and `message` fields below.

        ```yaml
            events:
            - !ruby/object:Puppet::Transaction::Event
              audited: false
              property: password
              previous_value: "[redacted]"
              desired_value: "[redacted]"
              historical_value:
              message: changed [redacted] to [redacted]
              name: :password_changed
              status: success
              time: 2017-05-17 16:06:02.934398293 -07:00
              redacted: true
              corrective_change: false
            corrective_change: false
        ```
        }

      validate do |value|
        raise ArgumentError, _("Passwords cannot include ':'") if value.is_a?(String) and value.include?(":")
      end

      sensitive true
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
          raise ArgumentError, _("Password minimum age must be provided as a number.")
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
          raise ArgumentError, _("Password maximum age must be provided as a number.")
        end
      end
    end

    newproperty(:password_warn_days, :required_features => :manages_password_age) do
      desc "The number of days before a password is going to expire (see the maximum password age) during which the user should be warned."

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
          raise ArgumentError, "Password warning days must be provided as a number."
        end
      end
    end

    newproperty(:groups, :parent => Puppet::Property::List) do
      desc "The groups to which the user belongs.  The primary group should
        not be listed, and groups should be identified by name rather than by
        GID.  Multiple groups should be specified as an array."

      validate do |value|
        if value =~ /^\d+$/
          raise ArgumentError, _("Group names must be provided, not GID numbers.")
        end
        raise ArgumentError, _("Group names must be provided as an array, not a comma-separated list.") if value.include?(",")
        raise ArgumentError, _("Group names must not be empty. If you want to specify \"no groups\" pass an empty array") if value.empty?
      end

      def change_to_s(currentvalue, newvalue)
        newvalue = newvalue.split(",") if newvalue != :absent

        if provider.respond_to?(:groups_to_s)
          # for Windows ADSI
          # de-dupe the "newvalue" when the sync event message is generated,
          # due to final retrieve called after the resource has been modified
          newvalue = provider.groups_to_s(newvalue).split(',').uniq
        end

        super(currentvalue, newvalue)
      end

      # override Puppet::Property::List#retrieve
      def retrieve
        if provider.respond_to?(:groups_to_s)
          # Windows ADSI groups returns SIDs, but retrieve needs names
          # must return qualified names for SIDs for "is" value and puppet resource
          return provider.groups_to_s(provider.groups).split(',')
        end

        super
      end

      def insync?(current)
        if provider.respond_to?(:groups_insync?)
          return provider.groups_insync?(current, @should)
        end

        super(current)
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
      desc "If `minimum` is specified, Puppet will ensure that the user is a
        member of all specified groups, but will not remove any other groups
        that the user is a part of.

        If `inclusive` is specified, Puppet will ensure that the user is a
        member of **only** specified groups.

        Defaults to `minimum`."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newparam(:system, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc "Whether the user is a system user, according to the OS's criteria;
      on most platforms, a UID less than or equal to 500 indicates a system
      user. This parameter is only used when the resource is created and will
      not affect the UID when the user is present. Defaults to `false`."

      defaultto false
    end

    newparam(:allowdupe, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc "Whether to allow duplicate UIDs. Defaults to `false`."

      defaultto false
    end

    newparam(:managehome, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc "Whether to manage the home directory when Puppet creates or removes the user.
        This creates the home directory if Puppet also creates the user account, and deletes the
        home directory if Puppet also removes the user account. Defaults to `false`.

        This parameter has no effect unless Puppet is also creating or removing the user in the
        resource at the same time. For instance, Puppet creates a home directory for a managed
        user if `ensure => present` and the user does not exist at the time of the Puppet run.
        If the home directory is then deleted manually, Puppet will not recreate it on the next
        run."

      defaultto false

      validate do |val|
        if munge(val)
          raise ArgumentError, _("User provider %{name} can not manage home directories") % { name: provider.class.name } if provider and not provider.class.manages_homedir?
        end
      end
    end

    newproperty(:expiry, :required_features => :manages_expiry) do
      desc "The expiry date for this user. Provide as either the special
           value `absent` to ensure that the account never expires, or as
           a zero-padded YYYY-MM-DD format -- for example, 2010-02-19."

      newvalues :absent
      newvalues(/^\d{4}-\d{2}-\d{2}$/)

      validate do |value|
        if value.intern != :absent and value !~ /^\d{4}-\d{2}-\d{2}$/
          #TRANSLATORS YYYY-MM-DD represents a date with a four-digit year, a two-digit month, and a two-digit day,
          #TRANSLATORS separated by dashes.
          raise ArgumentError, _("Expiry dates must be YYYY-MM-DD or the string \"absent\"")
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

    # This method has been exposed for puppet to manage users and groups of
    # files in its settings and should not be considered available outside of
    # puppet.
    #
    # (see Puppet::Settings#service_user_available?)
    #
    # @return [Boolean] if the user exists on the system
    # @api private
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
          raise ArgumentError, _("Role names must be provided, not numbers")
        end
        raise ArgumentError, _("Role names must be provided as an array, not a comma-separated list") if value.include?(",")
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
          raise ArgumentError, _("Auth names must be provided, not numbers")
        end
        raise ArgumentError, _("Auth names must be provided as an array, not a comma-separated list") if value.include?(",")
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
          raise ArgumentError, _("Profile names must be provided, not numbers")
        end
        raise ArgumentError, _("Profile names must be provided as an array, not a comma-separated list") if value.include?(",")
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
        raise ArgumentError, _("Key/value pairs must be separated by an =") unless value.include?("=")
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
        raise ArgumentError, _("Attributes value pairs must be separated by an =") unless value.include?("=")
      end
    end

    newparam(:attribute_membership) do
      desc "Whether specified attribute value pairs should be treated as the
        **complete list** (`inclusive`) or the **minimum list** (`minimum`) of
        attribute/value pairs for the user. Defaults to `minimum`."

      newvalues(:inclusive, :minimum)

      defaultto :minimum
    end

    newproperty(:salt, :required_features => :manages_password_salt) do
      desc "This is the 32-byte salt used to generate the PBKDF2 password used in
            OS X. This field is required for managing passwords on OS X >= 10.8."
    end

    newproperty(:iterations, :required_features => :manages_password_salt) do
      desc "This is the number of iterations of a chained computation of the
            [PBKDF2 password hash](https://en.wikipedia.org/wiki/PBKDF2). This parameter
            is used in OS X, and is required for managing passwords on OS X 10.8 and
            newer."

      munge do |value|
        if value.is_a?(String) and value =~/^[-0-9]+$/
          Integer(value)
        else
          value
        end
      end
    end

    newparam(:forcelocal, :boolean => true,
            :required_features => :libuser,
            :parent => Puppet::Parameter::Boolean) do
      desc "Forces the management of local accounts when accounts are also
            being managed by some other NSS"
      defaultto false
    end

    def generate
      return [] if self[:purge_ssh_keys].empty?
      find_unmanaged_keys
    end

    newparam(:purge_ssh_keys) do
      desc "Whether to purge authorized SSH keys for this user if they are not managed
        with the `ssh_authorized_key` resource type. Allowed values are:

        * `false` (default) --- don't purge SSH keys for this user.
        * `true` --- look for keys in the `.ssh/authorized_keys` file in the user's
          home directory. Purge any keys that aren't managed as `ssh_authorized_key`
          resources.
        * An array of file paths --- look for keys in all of the files listed. Purge
          any keys that aren't managed as `ssh_authorized_key` resources. If any of
          these paths starts with `~` or `%h`, that token will be replaced with
          the user's home directory."

      defaultto :false

      # Use Symbols instead of booleans until PUP-1967 is resolved.
      newvalues(:true, :false)

      validate do |value|
        if [ :true, :false ].include? value.to_s.intern
          return
        end
        value = [ value ] if value.is_a?(String)
        if value.is_a?(Array)
          value.each do |entry|

            raise ArgumentError, _("Each entry for purge_ssh_keys must be a string, not a %{klass}") % { klass: entry.class } unless entry.is_a?(String)

            valid_home = Puppet::Util.absolute_path?(entry) || entry =~ %r{^~/|^%h/}
            raise ArgumentError, _("Paths to keyfiles must be absolute, not %{entry}") % { entry: entry } unless valid_home
          end
          return
        end
        raise ArgumentError, _("purge_ssh_keys must be true, false, or an array of file names, not %{value}") % { value: value.inspect }
      end

      munge do |value|
        # Resolve string, boolean and symbol forms of true and false to a
        # single representation.
        test_sym = value.to_s.intern
        value = test_sym if [:true, :false].include? test_sym

        return [] if value == :false
        home = resource[:home]
        if value == :true and not home
          raise ArgumentError, _("purge_ssh_keys can only be true for users with a defined home directory")
        end

        return [ "#{home}/.ssh/authorized_keys" ] if value == :true
        # value is an array - munge each value
        [ value ].flatten.map do |entry|
          if entry =~ /^~|^%h/ and not home
            raise ArgumentError, _("purge_ssh_keys value '%{value}' meta character ~ or %{home_placeholder} only allowed for users with a defined home directory") % { value: value, home_placeholder: '%h' }
          end
          entry.gsub!(/^~\//, "#{home}/")
          entry.gsub!(/^%h\//, "#{home}/")
          entry
        end
      end
    end

    newproperty(:loginclass, :required_features => :manages_loginclass) do
      desc "The name of login class to which the user belongs."

      validate do |value|
        if value =~ /^\d+$/
          raise ArgumentError, _("Class name must be provided.")
        end
      end
    end

    # Generate ssh_authorized_keys resources for purging. The key files are
    # taken from the purge_ssh_keys parameter. The generated resources inherit
    # all metaparameters from the parent user resource.
    #
    # @return [Array<Puppet::Type::Ssh_authorized_key] a list of resources
    #   representing the found keys
    # @see generate
    # @api private
    def find_unmanaged_keys
      self[:purge_ssh_keys].
        select { |f| File.readable?(f) }.
        map { |f| unknown_keys_in_file(f) }.
        flatten.each do |res|
          res[:ensure] = :absent
          res[:user] = self[:name]
          @parameters.each do |name, param|
            res[name] = param.value if param.metaparam?
          end
        end
    end

    # Parse an ssh authorized keys file superficially, extract the comments
    # on the keys. These are considered names of possible ssh_authorized_keys
    # resources. Keys that are managed by the present catalog are ignored.
    #
    # @see generate
    # @api private
    # @return [Array<Puppet::Type::Ssh_authorized_key] a list of resources
    #   representing the found keys
    def unknown_keys_in_file(keyfile)
      names = []
      name_index = 0
      # RFC 4716 specifies UTF-8 allowed in public key files per https://www.ietf.org/rfc/rfc4716.txt
      # the authorized_keys file may contain UTF-8 comments
      Puppet::FileSystem.open(keyfile, nil, 'r:UTF-8').each do |line|
        next unless line =~ Puppet::Type.type(:ssh_authorized_key).keyline_regex
        # the name is stored in the 4th capture of the regex
        name = $4
        if name.empty?
          $3.delete("\n")
          # If no comment is specified for this key, generate a unique internal
          # name. This uses the same rules as
          # provider/ssh_authorized_key/parsed (PUP-3357)
          name = "#{keyfile}:unnamed-#{name_index += 1}"
        end
        names << name
        Puppet.debug "#{self.ref} parsed for purging Ssh_authorized_key[#{name}]"
      end

      names.map { |keyname|
        Puppet::Type.type(:ssh_authorized_key).new(
          :name => keyname,
          :target => keyfile)
      }.reject { |res|
        catalog.resource_refs.include? res.ref
      }
    end
  end
end
