require 'puppet/provider/parsedfile'

Puppet::Type.type(:host).provide :parsed, :parent => Puppet::Provider::ParsedFile do
    @path = "/etc/hosts"
    @filetype = Puppet::FileType.filetype(:flat)

    confine :exists => @path

    # Parse a host file
    #
    # This method also stores existing comments, and it stores all host
    # jobs in order, mostly so that comments are retained in the order
    # they were written and in proximity to the same jobs.
    def self.parse(text)
        count = 0
        instances = []
        text.chomp.split("\n").each { |line|
            hash = {}
            case line
            when /^#/, /^\s*$/:
                # add comments and blank lines to the list as they are
                instances << line 
            else
                if line.sub!(/^(\S+)\s+(\S+)\s*/, '')
                    hash[:ip] = $1
                    hash[:name] = $2

                    unless line == ""
                        line.sub!(/\s*/, '')
                        line.sub!(/^([^#]+)\s*/) do |value|
                            aliases = $1
                            unless aliases =~ /^\s*$/
                                hash[:alias] = aliases.split(/\s+/)
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

                instances << hash

                count += 1
            end
        }

        return instances
    end

    # Convert the current object into a host-style string.
    def self.to_record(hash)
        [:ip, :name].each do |n|
            unless hash.has_key? n
                raise ArgumentError, "%s is a required attribute for hosts" % n
            end
        end

        str = "%s\t%s" % [hash[:ip], hash[:name]]

        if hash.include? :alias
            if hash[:alias].is_a? Array
                str += "\t%s" % hash[:alias].join("\t")
            else
                raise ArgumentError, "Aliases must be specified as an array"
            end
        end

        str
    end
end

# $Id$
