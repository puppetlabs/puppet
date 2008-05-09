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

    def prefetch
        if not @resource.should(:target)
            #
            # Set default target when user is given
            if val = @resource.should(:user)
                target =  File.expand_path("~%s/.ssh/authorized_keys" % val)
                Puppet::debug("Setting target to %s" % target)
                @resource[:target] = target
            else
                raise Puppet::Error, "Missing attribute 'user' or 'target'"
            end
        end

        super
    end
end

