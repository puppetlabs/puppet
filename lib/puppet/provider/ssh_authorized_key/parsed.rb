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
        :match    => /^(?:(.+) )?(ssh-dss|ssh-rsa) ([^ ]+)(?: (.+))?$/,
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

    record_line :key_v1,
        :fields   => %w{options bits exponent modulus name},
        :optional => %w{options},
        :rts      => /^\s+/,
        :match    => /^(?:(.+) )?(\d+) (\d+) (\d+)(?: (.+))?$/

    def prefetch
        # This was done in the type class but path expansion was failing for
        # not yet existing users, the only workaround I found was to move that
        # in the provider.
        if user = @resource.should(:user)
            target = File.expand_path("~%s/.ssh/authorized_keys" % user)
            @property_hash[:target] = target
            @resource[:target] = target
        end

        super
    end

    def flush
        # As path expansion had to be moved in the provider, we cannot generate new file
        # resources and thus have to chown and chmod here. It smells hackish.
        
        # Create target's parent directory if nonexistant
        if target = @property_hash[:target]
            dir = File.dirname(@property_hash[:target])
            if not File.exist? dir
                Puppet.debug("Creating directory %s which did not exist" % dir)
                Dir.mkdir(dir, 0700)
            end
        end

        # Generate the file
        super

        # Ensure correct permissions
        if target and user = @property_hash[:user]
            File.chown(Puppet::Util.uid(user), nil, dir)
            File.chown(Puppet::Util.uid(user), nil, @property_hash[:target])
        end
    end
end

