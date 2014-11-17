module Puppet
  Type.newtype(:ssh_authorized_key) do
    @doc = "Manages SSH authorized keys. Currently only type 2 keys are supported.

      In their native habitat, SSH keys usually appear as a single long line. This
      resource type requires you to split that line into several attributes. Thus, a
      key that appears in your `~/.ssh/id_rsa.pub` file like this...

          ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAy5mtOAMHwA2ZAIfW6Ap70r+I4EclYHEec5xIN59ROUjss23Skb1OtjzYpVPaPH8mSdSmsN0JHaBLiRcu7stl4O8D8zA4mz/vw32yyQ/Kqaxw8l0K76k6t2hKOGqLTY4aFbFISV6GDh7MYLn8KU7cGp96J+caO5R5TqtsStytsUhSyqH+iIDh4e4+BrwTc6V4Y0hgFxaZV5d18mLA4EPYKeG5+zyBCVu+jueYwFqM55E0tHbfiaIN9IzdLV+7NEEfdLkp6w2baLKPqWUBmuvPF1Mn3FwaFLjVsMT3GQeMue6b3FtUdTDeyAYoTxrsRo/WnDkS6Pa3YhrFwjtUqXfdaQ== nick@magpie.puppetlabs.lan

      ...would translate to the following resource:

          ssh_authorized_key { 'nick@magpie.puppetlabs.lan':
            user => 'nick',
            type => 'ssh-rsa',
            key  => 'AAAAB3NzaC1yc2EAAAABIwAAAQEAy5mtOAMHwA2ZAIfW6Ap70r+I4EclYHEec5xIN59ROUjss23Skb1OtjzYpVPaPH8mSdSmsN0JHaBLiRcu7stl4O8D8zA4mz/vw32yyQ/Kqaxw8l0K76k6t2hKOGqLTY4aFbFISV6GDh7MYLn8KU7cGp96J+caO5R5TqtsStytsUhSyqH+iIDh4e4+BrwTc6V4Y0hgFxaZV5d18mLA4EPYKeG5+zyBCVu+jueYwFqM55E0tHbfiaIN9IzdLV+7NEEfdLkp6w2baLKPqWUBmuvPF1Mn3FwaFLjVsMT3GQeMue6b3FtUdTDeyAYoTxrsRo/WnDkS6Pa3YhrFwjtUqXfdaQ==',
          }

      To ensure that only the currently approved keys are present, you can purge
      unmanaged SSH keys on a per-user basis. Do this with the `user` resource
      type's `purge_ssh_keys` attribute:

          user { 'nick':
            ensure         => present,
            purge_ssh_keys => true,
          }

      This will remove any keys in `~/.ssh/authorized_keys` that aren't being
      managed with `ssh_authorized_key` resources. See the documentation of the
      `user` type for more details.

      **Autorequires:** If Puppet is managing the user account in which this
      SSH key should be installed, the `ssh_authorized_key` resource will autorequire
      that user."

    ensurable

    newparam(:name) do
      desc "The SSH key comment. This attribute is currently used as a
        system-wide primary key and therefore has to be unique."

      isnamevar

    end

    newproperty(:type) do
      desc "The encryption type used."

      newvalues :'ssh-dss', :'ssh-rsa', :'ecdsa-sha2-nistp256', :'ecdsa-sha2-nistp384', :'ecdsa-sha2-nistp521', :'ssh-ed25519'

      aliasvalue(:dsa, :'ssh-dss')
      aliasvalue(:ed25519, :'ssh-ed25519')
      aliasvalue(:rsa, :'ssh-rsa')
    end

    newproperty(:key) do
      desc "The public key itself; generally a long string of hex characters. The `key`
        attribute may not contain whitespace.

        Make sure to omit the following in this attribute (and specify them in
        other attributes):

        * Key headers (e.g. 'ssh-rsa') --- put these in the `type` attribute.
        * Key identifiers / comments (e.g. 'joe@joescomputer.local') --- put these in
          the `name` attribute/resource title."

      validate do |value|
        raise Puppet::Error, "Key must not contain whitespace: #{value}" if value =~ /\s/
      end
    end

    newproperty(:user) do
      desc "The user account in which the SSH key should be installed. The resource
        will autorequire this user if it is being managed as a `user` resource."
    end

    newproperty(:target) do
      desc "The absolute filename in which to store the SSH key. This
        property is optional and should only be used in cases where keys
        are stored in a non-standard location (i.e.` not in
        `~user/.ssh/authorized_keys`)."

      defaultto :absent

      def should
        return super if defined?(@should) and @should[0] != :absent

        return nil unless user = resource[:user]

        begin
          return File.expand_path("~#{user}/.ssh/authorized_keys")
        rescue
          Puppet.debug "The required user is not yet present on the system"
          return nil
        end
      end

      def insync?(is)
        is == should
      end
    end

    newproperty(:options, :array_matching => :all) do
      desc "Key options; see sshd(8) for possible values. Multiple values
        should be specified as an array."

      defaultto do :absent end

      def is_to_s(value)
        if value == :absent or value.include?(:absent)
          super
        else
          value.join(",")
        end
      end

      def should_to_s(value)
        if value == :absent or value.include?(:absent)
          super
        else
          value.join(",")
        end
      end

      validate do |value|
        unless value == :absent or value =~ /^[-a-z0-9A-Z_]+(?:=\".*?\")?$/
          raise Puppet::Error, "Option #{value} is not valid. A single option must either be of the form 'option' or 'option=\"value\". Multiple options must be provided as an array"
        end
      end
    end

    autorequire(:user) do
      should(:user) if should(:user)
    end

    validate do
      # Go ahead if target attribute is defined
      return if @parameters[:target].shouldorig[0] != :absent

      # Go ahead if user attribute is defined
      return if @parameters.include?(:user)

      # If neither target nor user is defined, this is an error
      raise Puppet::Error, "Attribute 'user' or 'target' is mandatory"
    end

    # regular expression suitable for use by a ParsedFile based provider
    REGEX = /^(?:(.+) )?(ssh-dss|ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ([^ ]+) ?(.*)$/
    def self.keyline_regex
      REGEX
    end
  end
end
