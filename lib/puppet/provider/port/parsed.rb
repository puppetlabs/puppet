require 'puppet/provider/parsedfile'

Puppet::Type.type(:port).provide :parsed, :parent => Puppet::Provider::ParsedFile do

    @filetype = Puppet::FileType.filetype(:flat)
    @path = "/etc/services"

    # Parse a services file
    #
    # This method also stores existing comments, and it stores all port
    # info in order, mostly so that comments are retained in the order
    # they were written and in proximity to the same ports.
    def self.parse(text)
        count = 0
        instances = []
        namehash = {} # For merging
        text.chomp.split("\n").each { |line|
            hash = {}
            case line
            when /^#/, /^\s*$/:
                # add comments and blank lines to the list as they are
                instances << line 
            else
                if line.sub!(/^(\S+)\s+(\d+)\/(\w+)\s*/, '')
                    hash[:name] = $1
                    hash[:number] = $2
                    hash[:protocols] = [$3]

                    unless line == ""
                        line.sub!(/^([^#]+)\s*/) do |value|
                            aliases = $1

                            # Remove any trailing whitespace
                            aliases.strip!
                            unless aliases =~ /^\s*$/
                                hash[:alias] = aliases.split(/\s+/)
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
                    if line =~ /^\s+\d+/ and
                        Facter["operatingsystem"].value == "Darwin"
                            #Puppet.notice "Skipping wonky OS X port entry %s" %
                            #    line.inspect
                            next
                    end
                    raise Puppet::Error, "Could not match '%s'" % line
                end

                # If there's already a service with this name, then check
                # to see if the only difference is the proto; if so, just
                # add our proto and walk away
                if obj = namehash[hash[:name]]
                    if portmerge(obj, hash)
                        next
                    end
                end

                instances << hash
                namehash[hash[:name]] = hash

                count += 1
            end
        }

        return instances
    end

    def self.portmerge(base, hash)
        unless base.has_key?(:protocols)
            return false
        end

        # This method is only called from parsing, so we only worry
        # about 'is' values.
        proto = base[:protocols]

        if proto.nil? or proto == :absent
            # We are an unitialized object; we've got 'should'
            # values but no 'is' values
            return false
        end

        # If this is happening, our object exists
        base[:ensure] = :present

        if hash[:protocols]
            # The protocol can be a symbol, so...
            if proto.is_a?(Symbol)
                proto = []
            end
            # Check to see if it already includes our proto
            unless proto.include?(hash[:protocols])
                # We are missing their proto
                proto += hash[:protocols]
                base[:protocols] = proto
            end
        end

        if hash.include?(:description) and ! base.include?(:description)
            base[:description] = hash[:description]
        end

        return true
    end

    # Convert the current object into one or more services entry.
    def self.to_record(hash)
        hash[:protocols].collect { |proto|
            str = "%s\t%s/%s" % [hash[:name], hash[:number], proto]

            if value = hash[:alias] and value != :absent
                str += "\t%s" % value.join(" ")
            else
                str += "\t"
            end

            if value = hash[:description] and value != :absent
                str += "\t# %s" % value
            else
                str += "\t"
            end
            str
        }.join("\n")
    end
end

# $Id$
