require 'puppet/property/ordered_list'

module Puppet
  newtype(:host) do
    ensurable

    newproperty(:ip) do
      desc "The host's IP address, IPv4 or IPv6."

      validate do |value|
        unless value =~ /^((([0-9a-fA-F]+:){7}[0-9a-fA-F]+)|(([0-9a-fA-F]+:)*[0-9a-fA-F]+)?::(([0-9a-fA-F]+:)*[0-9a-fA-F]+)?)|((25[0-5]|2[0-4][\d]|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3})$/
          raise Puppet::Error, "Invalid IP address"
        end
      end

    end

    # for now we use OrderedList to indicate that the order does matter.
    newproperty(:host_aliases, :parent => Puppet::Property::OrderedList) do
      desc "Any aliases the host might have.  Multiple values must be
        specified as an array."

      def delimiter
        " "
      end

      def inclusive?
        true
      end

      validate do |value|
        raise Puppet::Error, "Host aliases cannot include whitespace" if value =~ /\s/
        raise Puppet::Error, "Host alias cannot be an empty string. Use an empty array to delete all host_aliases " if value =~ /^\s*$/
      end

    end

    newproperty(:comment) do
      desc "A comment that will be attached to the line with a # character."
    end

    newproperty(:target) do
      desc "The file in which to store service information.  Only used by
        those providers that write to disk. On most systems this defaults to `/etc/hosts`."

      defaultto { if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
        @resource.class.defaultprovider.default_target
        else
          nil
        end
      }
    end

    newparam(:name) do
      desc "The host name."

      isnamevar

      validate do |value|
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
        x = value.split('.').each do |hostpart|
          unless hostpart =~ /^([\d\w]+|[\d\w][\d\w\-]+[\d\w])$/
            raise Puppet::Error, "Invalid host name"
          end
        end
      end
    end

    @doc = "Installs and manages host entries.  For most systems, these
      entries will just be in `/etc/hosts`, but some systems (notably OS X)
      will have different solutions."
  end
end
