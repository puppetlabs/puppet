require 'etc'
require 'facter'
require 'puppet/type/parsedtype'
require 'puppet/type/state'

module Puppet
    newtype(:host, Puppet::Type::ParsedType) do

        newstate(:ip) do
            desc "The host's IP address."
        end

        newstate(:alias) do
            desc "Any alias the host might have.  Multiple values must be
                specified as an array.  Note that this state has the same name
                as one of the metaparams; using this state to set aliases will
                make those aliases available in your Puppet scripts and also on
                disk."

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
                    return @should
                else
                    return []
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
                # Add the :alias metaparam in addition to the state
                @parent.newmetaparam(@parent.class.metaparamclass(:alias), value)
                value
            end
        end

        newparam(:name) do
            desc "The host name."

            isnamevar
        end

        @doc = "Installs and manages host entries.  For most systems, these
            entries will just be in /etc/hosts, but some systems (notably OS X)
            will have different solutions."

        @instances = []

        @path = "/etc/hosts"
        @fields = [:ip, :name, :alias]

        @filetype = Puppet::FileType.filetype(:flat)

        # Parse a host file
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
                    if line.sub!(/^(\S+)\s+(\S+)\s*/, '')
                        hash[:ip] = $1
                        hash[:name] = $2

                        unless line == ""
                            line.sub!(/\s*/, '')
                            line.sub!(/^([^#]+)\s*/) do |value|
                                aliases = $1
                                unless aliases =~ /^\s*$/
                                    hash[:alias] = aliases
                                end

                                ""
                            end
                        end
                    else
                        raise Puppet::Error, "Could not match '%s'" % line
                    end

                    if hash[:alias] == ""
                        hash.delete(:alias)
                    end

                    hash2obj(hash)

                    hash.clear
                    count += 1
                end
            }
        end

        # Convert the current object into a host-style string.
        def to_record
            str = "%s\t%s" % [self.state(:ip).value, self[:name]]

            if value = self.value(:alias)
                str += "\t%s" % value.join("\t")
            end

            str
        end
    end
end

# $Id$
