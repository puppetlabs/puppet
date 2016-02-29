module Puppet
  Type.newtype(:sshkey) do
    @doc = "Installs and manages ssh host keys.  By default, this type will
      install keys into `/etc/ssh/ssh_known_hosts`. To manage ssh keys in a
      different `known_hosts` file, such as a user's personal `known_hosts`,
      pass its path to the `target` parameter. See the `ssh_authorized_key`
      type to manage authorized keys."

    ensurable

    newproperty(:type) do
      desc "The encryption type used.  Probably ssh-dss or ssh-rsa."

      newvalues :'ssh-dss', :'ssh-ed25519', :'ssh-rsa', :'ecdsa-sha2-nistp256', :'ecdsa-sha2-nistp384', :'ecdsa-sha2-nistp521'

      aliasvalue(:dsa, :'ssh-dss')
      aliasvalue(:ed25519, :'ssh-ed25519')
      aliasvalue(:rsa, :'ssh-rsa')
    end

    newproperty(:key) do
      desc "The key itself; generally a long string of uuencoded characters."
    end

    # FIXME This should automagically check for aliases to the hosts, just
    # to see if we can automatically glean any aliases.
    newproperty(:host_aliases) do
      desc 'Any aliases the host might have.  Multiple values must be
        specified as an array.'

      attr_accessor :meta

      def insync?(is)
        is == @should
      end
      # We actually want to return the whole array here, not just the first
      # value.
      def should
        defined?(@should) ? @should : nil
      end

      validate do |value|
        if value =~ /\s/
          raise Puppet::Error, "Aliases cannot include whitespace"
        end
        if value =~ /,/
          raise Puppet::Error, "Aliases must be provided as an array, not a comma-separated list"
        end
      end
    end

    newparam(:name) do
      desc "The host name that the key is associated with."

      isnamevar

      validate do |value|
        raise Puppet::Error, "Resourcename cannot include whitespaces" if value =~ /\s/
        raise Puppet::Error, "No comma in resourcename allowed. If you want to specify aliases use the host_aliases property" if value.include?(',')
      end
    end

    newproperty(:target) do
      desc "The file in which to store the ssh key.  Only used by
        the `parsed` provider."

      defaultto { if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
        @resource.class.defaultprovider.default_target
        else
          nil
        end
      }
    end
  end
end
