module Puppet
    newtype(:ssh_authorized_key) do
        @doc = "Manages ssh authorized keys."

        ensurable

        newparam(:name) do
            desc "The ssh key comment."

            isnamevar
        end

        newproperty(:type) do
            desc "The encryption type used.  Probably ssh-dss or ssh-rsa for
                  ssh version 2. Not used for ssh version 1."

            newvalue("ssh-dss")
            newvalue("ssh-rsa")

            aliasvalue(:dsa, "ssh-dss")
            aliasvalue(:rsa, "ssh-rsa")
        end

        newproperty(:key) do
            desc "The key itself; generally a long string of hex digits."
        end

        newproperty(:user) do
            desc "The user account in which the ssh key should be installed."
        end

        newproperty(:target) do
            desc "The file in which to store the ssh key."
        end

        newproperty(:options, :array_matching => :all) do
            desc "Key options, see sshd(8) for possible values. Multiple values
              should be specified as an array."

            defaultto do :absent end
        end
    end
end

