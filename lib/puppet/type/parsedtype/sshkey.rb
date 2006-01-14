require 'etc'
require 'facter'
require 'puppet/type/parsedtype'
require 'puppet/type/state'

module Puppet
    newtype(:sshkey, Puppet::Type::ParsedType) do
        isaggregatable

        newstate(:type) do
            desc "The encryption type used.  Probably ssh-dss or ssh-rsa."
        end

        newstate(:key) do
            desc "The key itself; generally a long string of hex digits."
        end

        # FIXME This should automagically check for aliases to the hosts, just
        # to see if we can automatically glean any aliases.
        newstate(:alias) do
            desc "Any alias the host might have.  Multiple values must be
                specified as an array.  Note that this state has the same name
                as one of the metaparams; using this state to set aliases will
                make those aliases available in your Puppet scripts and also on
                disk."

            # We actually want to return the whole array here, not just the first
            # value.
            def should
                @should
            end

            validate do |value|
                if value =~ /\s/
                    raise Puppet::Error, "Aliases cannot include whitespace"
                end
                if value =~ /,/
                    raise Puppet::Error, "Aliases cannot include whitespace"
                end
            end

            # Make a puppet alias in addition.
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

        @path = "/etc/ssh/ssh_known_hosts"
        @fields = [:name, :type, :key]

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
                    hash = {}
                    fields().zip(line.split(" ")).each { |param, value|
                        hash[param] = value
                    }

                    if hash[:name] =~ /,/
                        names = hash[:name].split(",")
                        hash[:name] = names.shift
                        hash[:alias] = names
                    end

                    #if match = /^(\S+)\s+(\S+)\s*(\S*)$/.match(line)
                    #    fields().zip(match.captures).each { |param, value|
                    #        hash[param] = value
                    #    }
                    #else
                    #    raise Puppet::Error, "Could not match '%s'" % line
                    #end

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
        def to_s
            name = self[:name]
            if @states.include?(:alias)
                name += "," + @states[:alias].should.join(",")
            end
            [name, @states[:type].should, @states[:key].should].join(" ")
        end
    end
end

# $Id$
