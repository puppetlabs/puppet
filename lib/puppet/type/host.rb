require 'etc'
require 'facter'
require 'puppet/type/parsedtype'
require 'puppet/type/state'

module Puppet
    newtype(:host, Puppet::Type::ParsedType) do
        newstate(:ip) do
            desc "The host's IP address."
        end

        newstate(:aliases) do
            desc "Any aliases the host might have.  Values can be either an array
                or a comma-separated list."

            # We have to override the feeding mechanism; it might be nil or 
            # white-space separated
            def is=(value)
                # If it's just whitespace, ignore it
                if value =~ /^\s+$/
                    @is = nil
                else
                    # Else split based on whitespace and store as an array
                    @is = value.split(/\s+/)
                end
            end

            # We actually want to return the whole array here, not just the first
            # value.
            def should
                @should
            end

            munge do |values|
                unless values.is_a?(Array)
                    values = [values]
                end
                # Split based on comma, then flatten the whole thing
                values.collect { |values|
                    values.split(/,\s*/)
                }.flatten
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
        @fields = [:ip, :name, :aliases]

        @filetype = Puppet::FileType.filetype(:flat)
#        case Facter["operatingsystem"].value
#        when "Solaris":
#            @filetype = Puppet::FileType::SunOS
#        else
#            @filetype = Puppet::CronType::Default
#        end

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
                    if match = /^(\S+)\s+(\S+)\s*(\S*)$/.match(line)
                        fields().zip(match.captures).each { |param, value|
                            hash[param] = value
                        }
                    else
                        raise Puppet::Error, "Could not match '%s'" % line
                    end

                    if hash[:aliases] == ""
                        hash.delete(:aliases)
                    end

                    hash2obj(hash)

                    hash.clear
                    count += 1
                end
            }
        end

        # Convert the current object into a host-style string.
        def to_str
            str = "%s\t%s" % [self.state(:ip).should, self[:name]]

            if state = self.state(:alias)
                str += "\t%s" % state.should.join("\t")
            end

            str
        end
    end
end

# $Id$
