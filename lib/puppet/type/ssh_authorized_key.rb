module Puppet
  newtype(:ssh_authorized_key) do
    @doc = "Manages SSH authorized keys. Currently only type 2 keys are
    supported.
    
    **Autorequires:** If Puppet is managing the user account in which this 
    SSH key should be installed, the `ssh_authorized_key` resource will autorequire
    that user."

    ensurable

    newparam(:name) do
      desc "The SSH key comment. This attribute is currently used as a
      system-wide primary key and therefore has to be unique."

      isnamevar

      validate do |value|
        raise Puppet::Error, "Resourcename must not contain whitespace: #{value}" if value =~ /\s/
      end
    end

    newproperty(:type) do
      desc "The encryption type used: ssh-dss or ssh-rsa."

      newvalue("ssh-dss")
      newvalue("ssh-rsa")

      aliasvalue(:dsa, "ssh-dss")
      aliasvalue(:rsa, "ssh-rsa")
    end

    newproperty(:key) do
      desc "The key itself; generally a long string of hex digits."

      validate do |value|
        raise Puppet::Error, "Key must not contain whitespace: #{value}" if value =~ /\s/
      end
    end

    newproperty(:user) do
      desc "The user account in which the SSH key should be installed.
      The resource will automatically depend on this user."
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
      desc "Key options, see sshd(8) for possible values. Multiple values
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
        raise Puppet::Error, "Options must be provided as an array, not a comma separated list" if value != :absent and value.include?(',')
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
  end
end
