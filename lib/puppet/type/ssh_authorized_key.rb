module Puppet
    newtype(:ssh_authorized_key) do
        @doc = "Manages SSH authorized keys. Currently only type 2 keys are
        supported."

        ensurable

        newparam(:name) do
            desc "The SSH key comment. This attribute is currently used as a
            system-wide primary key and therefore has to be unique."

            isnamevar
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
        end

        newproperty(:user) do
            desc "The user account in which the SSH key should be installed.
            The resource will automatically depend on this user."
        end

        newproperty(:target) do
            desc "The absolute filename in which to store the SSH key. This
            property is optional and should only be used in cases where keys
            are stored in a non-standard location (ie not in
            ~user/.ssh/authorized_keys)."

            defaultto :absent

            def should
                if defined? @should and @should[0] != :absent
                    return super
                end

                return nil unless user = resource[:user]

                begin
                    return File.expand_path("~%s/.ssh/authorized_keys" % user)
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
        end

        autorequire(:user) do
            if should(:user)
                should(:user)
            end
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

