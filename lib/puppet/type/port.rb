#module Puppet
#    newtype(:port) do
#        @doc = "Installs and manages port entries.  For most systems, these
#            entries will just be in /etc/services, but some systems (notably OS X)
#            will have different solutions."
#
#        ensurable
#
#        newproperty(:protocols) do
#            desc "The protocols the port uses.  Valid values are *udp* and *tcp*.
#                Most services have both protocols, but not all.  If you want
#                both protocols, you must specify that; Puppet replaces the
#                current values, it does not merge with them.  If you specify
#                multiple protocols they must be as an array."
#
#            def is=(value)
#                case value
#                when String
#                    @is = value.split(/\s+/)
#                else
#                    @is = value
#                end
#            end
#
#            def is
#                @is
#            end
#
#            # We actually want to return the whole array here, not just the first
#            # value.
#            def should
#                if defined? @should
#                    if @should[0] == :absent
#                        return :absent
#                    else
#                        return @should
#                    end
#                else
#                    return nil
#                end
#            end
#
#            validate do |value|
#                valids = ["udp", "tcp", "ddp", :absent]
#                unless valids.include? value
#                    raise Puppet::Error,
#                        "Protocols can be either 'udp' or 'tcp', not %s" % value
#                end
#            end
#        end
#
#        newproperty(:number) do
#            desc "The port number."
#        end
#
#        newproperty(:description) do
#            desc "The port description."
#        end
#
#        newproperty(:port_aliases) do
#            desc 'Any aliases the port might have.  Multiple values must be
#                specified as an array.  Note that this property is not the same as
#                the "alias" metaparam; use this property to add aliases to a port
#                in the services file, and "alias" to aliases for use in your Puppet 
#                scripts.'
#
#            # We actually want to return the whole array here, not just the first
#            # value.
#            def should
#                if defined? @should
#                    if @should[0] == :absent
#                        return :absent
#                    else
#                        return @should
#                    end
#                else
#                    return nil
#                end
#            end
#
#            validate do |value|
#                if value.is_a? String and value =~ /\s/
#                    raise Puppet::Error,
#                        "Aliases cannot have whitespace in them: %s" %
#                        value.inspect
#                end
#            end
#
#            munge do |value|
#                unless value == "absent" or value == :absent
#                    # Add the :alias metaparam in addition to the property
#                    @resource.newmetaparam(
#                        @resource.class.metaparamclass(:alias), value
#                    )
#                end
#                value
#            end
#        end
#
#        newproperty(:target) do
#            desc "The file in which to store service information.  Only used by
#                those providers that write to disk."
#
#            defaultto { if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
#                    @resource.class.defaultprovider.default_target
#                else
#                    nil
#                end
#            }
#        end
#
#        newparam(:name) do
#            desc "The port name."
#
#            isnamevar
#        end
#    end
#end

