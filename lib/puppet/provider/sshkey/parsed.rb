require 'puppet/provider/parsedfile'

Puppet::Type.type(:sshkey).provide :parsed, :parent => Puppet::Provider::ParsedFile do
    @filetype = Puppet::FileType.filetype(:flat)
    @path = "/etc/ssh/ssh_known_hosts"
    @fields = [:name, :type, :key]

    # Parse an sshknownhosts file
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
                hash = {}
                fields().zip(line.split(" ")).each { |param, value|
                    hash[param] = value
                }

                if hash[:name] =~ /,/
                    names = hash[:name].split(",")
                    hash[:name] = names.shift
                    hash[:alias] = names
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

    # Convert the current object into an entry for a known-hosts file.
    def self.to_record(hash)
        name = hash[:name]
        if hash.include?(:alias)
            name += "," + hash[:alias].join(",")
        end
        [name, hash[:type], hash[:key]].join(" ")
    end
end

# $Id$
