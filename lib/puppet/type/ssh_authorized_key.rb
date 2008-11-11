module Puppet
    newtype(:ssh_authorized_key) do
        @doc = "Manages SSH authorized keys. Currently only type 2 keys are
        supported."

        ensurable

        newparam(:name) do
            desc "The SSH key comment."

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
            desc "The user account in which the SSH key should be installed."
        end

        newproperty(:target) do
            desc "The file in which to store the SSH key."
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
            unless should(:target) or should(:user)
                raise Puppet::Error, "Attribute 'user' or 'target' is mandatory"
            end
        end
    end
end

