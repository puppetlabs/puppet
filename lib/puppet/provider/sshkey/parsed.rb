require 'puppet/provider/parsedfile'

known = nil
case Facter.value(:operatingsystem)
when "Darwin"; known = "/etc/ssh_known_hosts"
else
    known = "/etc/ssh/ssh_known_hosts"
end

Puppet::Type.type(:sshkey).provide(:parsed,
    :parent => Puppet::Provider::ParsedFile,
    :default_target => known,
    :filetype => :flat
) do
    desc "Parse and generate host-wide known hosts files for SSH."

    text_line :comment, :match => /^#/
    text_line :blank, :match => /^\s+/

    record_line :parsed, :fields => %w{name type key},
        :post_parse => proc { |hash|
            names = hash[:name].split(",", -1)
            hash[:name]  = names.shift
            hash[:host_aliases] = names
        },
        :pre_gen => proc { |hash|
            if hash[:host_aliases]
                names = [hash[:name], hash[:host_aliases]].flatten

                hash[:name] = [hash[:name], hash[:host_aliases]].flatten.join(",")
                hash.delete(:host_aliases)
            end
        }
end

