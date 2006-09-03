require 'etc'
require 'facter'
require 'puppet/type/parsedtype'
require 'puppet/type/state'

module Puppet
    newtype(:port, Puppet::Type::ParsedType) do

        @doc = "Installs and manages port entries.  For most systems, these
            entries will just be in /etc/services, but some systems (notably OS X)
            will have different solutions."

        newstate(:protocols) do
            desc "The protocols the port uses.  Valid values are *udp* and *tcp*.
                Most services have both protocols, but not all.  If you want
                both protocols, you must specify that; Puppet replaces the
                current values, it does not merge with them.  If you specify
                multiple protocols they must be as an array."

            def is=(value)
                case value
                when String
                    @is = value.split(/\s+/)
                else
                    @is = value
                end
            end

            def is
                @is
            end

            # We actually want to return the whole array here, not just the first
            # value.
            def should
                if defined? @should
                    if @should[0] == :absent
                        return :absent
                    else
                        return @should
                    end
                else
                    return nil
                end
            end

            validate do |value|
                valids = ["udp", "tcp", "ddp", :absent]
                unless valids.include? value
                    raise Puppet::Error,
                        "Protocols can be either 'udp' or 'tcp', not %s" % value
                end
            end
        end

        newstate(:number) do
            desc "The port number."
        end

        newstate(:description) do
            desc "The port description."
            isoptional
        end

        newstate(:alias) do
            desc "Any aliases the port might have.  Multiple values must be
                specified as an array.  Note that this state has the same name as
                one of the metaparams; using this state to set aliases will make
                those aliases available in your Puppet scripts and also on disk."

            isoptional

            # We have to override the feeding mechanism; it might be nil or 
            # white-space separated
            def is=(value)
                # If it's just whitespace, ignore it
                case value
                when /^\s+$/
                    @is = nil
                when String
                    @is = value.split(/\s+/)
                when Symbol
                    @is = value
                else
                    raise Puppet::DevError, "Invalid value %s" % value.inspect
                end
            end

            # We actually want to return the whole array here, not just the first
            # value.
            def should
                if defined? @should
                    if @should[0] == :absent
                        return :absent
                    else
                        return @should
                    end
                else
                    return nil
                end
            end

            validate do |value|
                if value.is_a? String and value =~ /\s/
                    raise Puppet::Error,
                        "Aliases cannot have whitespace in them: %s" %
                        value.inspect
                end
            end

            munge do |value|
                unless value == "absent" or value == :absent
                    # Add the :alias metaparam in addition to the state
                    @parent.newmetaparam(
                        @parent.class.metaparamclass(:alias), value
                    )
                end
                value
            end
        end

        newparam(:name) do
            desc "The port name."

            isnamevar
        end
    end
end

# $Id$
