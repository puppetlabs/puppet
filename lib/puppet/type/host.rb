module Puppet
    newtype(:host) do
        ensurable

        newproperty(:ip) do
            desc "The host's IP address, IPv4 or IPv6."

        validate do |value|
           unless value =~ /((([0-9a-fA-F]+:){7}[0-9a-fA-F]+)|(([0-9a-fA-F]+:)*[0-9a-fA-F]+)?::(([0-9a-fA-F]+:)*[0-9a-fA-F]+)?)|((25[0-5]|2[0-4][\d]|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3})/
             raise Puppet::Error, "Invalid IP address"
           end
        end

        end

        newproperty(:host_aliases) do
            desc 'Any aliases the host might have.  Multiple values must be
                specified as an array.  Note that this property is not the same as
                the "alias" metaparam; use this property to add aliases to a host
                on disk, and "alias" to aliases for use in your Puppet scripts.'

           def insync?(is)
                is == @should
            end

            def is_to_s(currentvalue = @is)
                currentvalue = [currentvalue] unless currentvalue.is_a? Array
                currentvalue.join(" ")
            end

            def retrieve
                is = super
                case is
                when String
                    is = is.split(/\s*,\s*/)
                when Symbol
                    is = [is]
                when Array
                    # nothing
                else
                    raise Puppet::DevError, "Invalid @is type %s" % is.class
                end
                return is
            end

            # We actually want to return the whole array here, not just the first
            # value.
            def should
                if defined? @should
                    if @should == [:absent]
                        return :absent
                    else
                        return @should
                    end
                else
                    return nil
                end
            end

            def should_to_s(newvalue = @should)
                newvalue.join(" ")
            end

            validate do |value|
                raise Puppet::Error, "Host aliases cannot include whitespace" if value =~ /\s/
            end
        end

        newproperty(:target) do
            desc "The file in which to store service information.  Only used by
                those providers that write to disk."

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
            entries will just be in ``/etc/hosts``, but some systems (notably OS X)
            will have different solutions."
    end
end

