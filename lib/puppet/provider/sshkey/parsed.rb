require 'puppet/provider/parsedfile'


known = nil
case Facter.value(:operatingsystem)
when "Darwin": known = "/etc/ssh_known_hosts"
else
    known = "/etc/ssh/ssh_known_hosts"
end

Puppet::Type.type(:sshkey).provide(:parsed,
    :parent => Puppet::Provider::ParsedFile,
    :default_target => known,
    :filetype => :flat
) do
    text_line :comment, :match => /^#/
    text_line :blank, :match => /^\s+/
    record_line :parsed, :fields => %w{name type key}
    
    # Override the line parsing a bit, so we can split the aliases out.
    def self.parse_line(line)
        hash = super
        if hash[:name] =~ /,/
            names = hash[:name].split(",")
            hash[:name] = names.shift
            hash[:alias] = names
        end
        hash
    end
        
    
    def self.to_line(hash)
        if hash[:alias]
            hash = hash.dup
            names = [hash[:name], hash[:alias]].flatten
            
            hash[:name] = [hash[:name], hash[:alias]].flatten.join(",")
            hash.delete(:alias)
        end
        super(hash)
    end
end

# $Id$
