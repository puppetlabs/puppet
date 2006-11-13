require 'puppet/type/parsedtype'

module Puppet
    newtype(:host) do
        ensurable

        newstate(:ip) do
            desc "The host's IP address, IPv4 or IPv6."
        end

        newstate(:alias) do
            desc "Any alias the host might have.  Multiple values must be
                specified as an array.  Note that this state has the same name
                as one of the metaparams; using this state to set aliases will
                make those aliases available in your Puppet scripts and also on
                disk."

            # Make sure our "is" value is always an array.
            def is
                current = super
                unless current.is_a? Array
                    current = [current]
                end
                current
            end

            def is_to_s
                self.is.join(" ")
            end

            # We have to override the feeding mechanism; it might be nil or 
            # white-space separated
            def is=(value)
                # If it's just whitespace, ignore it
                case value
                when /^\s+$/
                    @is = nil
                when String
                    @is = value.split(/\s+/)
                else
                    @is = value
                end
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

            def should_to_s
                @should.join(" ")
            end

            validate do |value|
                if value =~ /\s/
                    raise Puppet::Error, "Aliases cannot include whitespace"
                end
            end

            munge do |value|
                if value == :absent or value == "absent"
                    :absent
                else
                    # Add the :alias metaparam in addition to the state
                    @parent.newmetaparam(@parent.class.metaparamclass(:alias), value)
                    value
                end
            end
        end

        newstate(:target) do
            desc "The file in which to store service information.  Only used by
                those providers that write to disk (i.e., not NetInfo)."

            defaultto { if @parent.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
                    @parent.class.defaultprovider.default_target
                else
                    nil
                end
            }
        end

        newparam(:name) do
            desc "The host name."

            isnamevar
        end

        @doc = "Installs and manages host entries.  For most systems, these
            entries will just be in /etc/hosts, but some systems (notably OS X)
            will have different solutions."
    end
end

# $Id$
