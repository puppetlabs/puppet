require 'etc'
require 'facter'
require 'puppet/type/parsedtype'
require 'puppet/type/state'

module Puppet
    newtype(:port, Puppet::Type::ParsedType) do
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

        @doc = "Installs and manages port entries.  For most systems, these
            entries will just be in /etc/services, but some systems (notably OS X)
            will have different solutions."

        @path = "/etc/services"
        @fields = [:ip, :name, :alias]

        @filetype = Puppet::FileType.filetype(:flat)

        # Parse a services file
        #
        # This method also stores existing comments, and it stores all host
        # jobs in order, mostly so that comments are retained in the order
        # they were written and in proximity to the same jobs.
        def self.parse(text)
            count = 0
            hash = {}
            text.chomp.split("\n").each { |line|
                case line
                when /^#/, /^\s*$/:
                    # add comments and blank lines to the list as they are
                    @instances << line 
                else
                    if line.sub!(/^(\S+)\s+(\d+)\/(\w+)\s*/, '')
                        hash[:name] = $1
                        hash[:number] = $2
                        hash[:protocols] = $3

                        unless line == ""
                            line.sub!(/^([^#]+)\s*/) do |value|
                                aliases = $1

                                # Remove any trailing whitespace
                                aliases.strip!
                                unless aliases =~ /^\s*$/
                                    hash[:alias] = aliases
                                end

                                ""
                            end

                            line.sub!(/^\s*#\s*(.+)$/) do |value|
                                desc = $1
                                unless desc =~ /^\s*$/
                                    hash[:description] = desc.sub(/\s*$/, '')
                                end

                                ""
                            end
                        end
                    else
                        raise Puppet::Error, "Could not match '%s'" % line
                    end

                    # If there's already a service with this name, then check
                    # to see if the only difference is the proto; if so, just
                    # add our proto and walk away
                    if obj = self[hash[:name]]
                        if obj.portmerge(hash)
                            next
                        end
                    end

                    hash2obj(hash)

                    hash.clear
                    count += 1
                end
            }
        end

        def portmerge(hash)
            unless @states.include?(:protocols)
                return false
            end

            # This method is only called from parsing, so we only worry
            # about 'is' values.
            proto = self.state(:protocols).is

            if proto.nil? or proto == :absent
                # We are an unitialized object; we've got 'should'
                # values but no 'is' values
                return false
            end

            # If this is happening, our object exists
            self.is = [:ensure, :present]

            if hash[:protocols]
                # The protocol can be a symbol, so...
                if proto.is_a?(Symbol)
                    proto = []
                end
                # Check to see if it already includes our proto
                unless proto.include?(hash[:protocols])
                    # We are missing their proto
                    proto << hash[:protocols]
                    @states[:protocols].is = proto
                end
            end

            if hash.include?(:description) and ! @states.include?(:description)
                self.is = [:description, hash[:description]]
            end

            return true
        end

        # Convert the current object into one or more services entry.
        def to_record
            self.state(:protocols).value.collect { |proto|
                str = "%s\t%s/%s" % [self[:name], self.value(:number),
                    proto]

                if value = self.value(:alias) and value != :absent
                    str += "\t%s" % value.join(" ")
                else
                    str += "\t"
                end

                if value = self.value(:description) and value != :absent
                    str += "\t# %s" % value
                else
                    str += "\t"
                end
                str
            }.join("\n")
        end
    end
end

# $Id$
