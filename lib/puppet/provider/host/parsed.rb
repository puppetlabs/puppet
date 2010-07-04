require 'puppet/provider/parsedfile'

hosts = nil
case Facter.value(:operatingsystem)
when "Solaris"; hosts = "/etc/inet/hosts"
else
    hosts = "/etc/hosts"
end

Puppet::Type.type(:host).provide(:parsed,
    :parent => Puppet::Provider::ParsedFile,
    :default_target => hosts,
    :filetype => :flat
) do
    confine :exists => hosts

    text_line :comment, :match => /^#/
    text_line :blank, :match => /^\s*$/

    record_line :parsed, :fields => %w{ip name host_aliases},
        :optional => %w{host_aliases},
        :rts => true do |line|
        hash = {}
        if line.sub!(/^(\S+)\s+(\S+)\s*/, '')
            hash[:ip] = $1
            hash[:name] = $2

            unless line == ""
                line.sub!(/\s*/, '')
                line.sub!(/^([^#]+)\s*/) do |value|
                    aliases = $1
                    unless aliases =~ /^\s*$/
                        hash[:host_aliases] = aliases.split(/\s+/)
                    end

                    ""
                end
            end
        else
            raise Puppet::Error, "Could not match '%s'" % line
        end

        if hash[:host_aliases] == ""
            hash.delete(:host_aliases)
        end

        return hash
    end

    # Convert the current object into a host-style string.
    def self.to_line(hash)
        return super unless hash[:record_type] == :parsed
        [:ip, :name].each do |n|
            unless hash[n] and hash[n] != :absent
                raise ArgumentError, "%s is a required attribute for hosts" % n
            end
        end

        str = "%s\t%s" % [hash[:ip], hash[:name]]

        if hash.include? :host_aliases
            if hash[:host_aliases].is_a? Array
                str += "\t%s" % hash[:host_aliases].join("\t")
            else
                raise ArgumentError, "Host aliases must be specified as an array"
            end
        end

        str
    end
end

