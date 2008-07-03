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

            def value=(value)
                @resource[:target] = File.expand_path("~%s/.ssh/authorized_keys" % value)
                super
            end
        end

        newproperty(:target) do
            desc "The file in which to store the ssh key."
        end

        newproperty(:options, :array_matching => :all) do
            desc "Key options, see sshd(8) for possible values. Multiple values
              should be specified as an array."

            defaultto do :absent end
        end

        def generate
            atype = Puppet::Type.type(:file)
            target = self.should(:target)
            dir =  File.dirname(target)
            user = should(:user) ? should(:user) : "root"

            rels = []

            unless catalog.resource(:file, dir)
                rels << atype.create(:name => dir, :ensure => :directory, :mode => 0700, :owner => user)
            end

            unless catalog.resource(:file, target)
                rels << atype.create(:name => target, :ensure => :present, :mode => 0600, :owner => user)
            end

            rels
        end

        autorequire(:user) do
            if should(:user)
                should(:user)
            end
        end

        validate do
            unless should(:target)
                raise Puppet::Error, "Attribute 'user' or 'target' is mandatory"
            end
        end
    end
end

