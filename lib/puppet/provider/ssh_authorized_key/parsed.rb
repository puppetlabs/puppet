require 'puppet/provider/parsedfile'

Puppet::Type.type(:ssh_authorized_key).provide(:parsed,
    :parent => Puppet::Provider::ParsedFile,
    :filetype => :flat,
    :default_target => ''
) do
    desc "Parse and generate authorized_keys files for SSH."

    text_line :comment, :match => /^#/
    text_line :blank, :match => /^\s+/

    record_line :parsed,
        :fields   => %w{options type key name},
        :optional => %w{options},
        :rts => /^\s+/,
        :match    => /^(?:([^ ]+) )?(ssh-dss|ssh-rsa) ([^ ]+)(?: (.+))?$/,
        :post_parse => proc { |record|
            if record[:options].nil?
                record[:options] = [:absent]
            else
                record[:options] = record[:options].split(',')
            end
        },
        :pre_gen => proc { |record|
            if record[:options].include?(:absent)
                record[:options] = ""
            else
                record[:options] = record[:options].join(',')
            end
        }
end

