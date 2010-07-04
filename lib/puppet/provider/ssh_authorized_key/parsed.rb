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
        :match    => /^(?:(.+) )?(ssh-dss|ssh-rsa) ([^ ]+) ?(.*)$/,
        :post_parse => proc { |h|
            h[:name] = "" if h[:name] == :absent
            h[:options] ||= [:absent]
            h[:options] = Puppet::Type::Ssh_authorized_key::ProviderParsed.parse_options(h[:options]) if h[:options].is_a? String
        },
        :pre_gen => proc { |h|
            h[:options] = [] if h[:options].include?(:absent)
            h[:options] = h[:options].join(',')
        }

    record_line :key_v1,
        :fields   => %w{options bits exponent modulus name},
        :optional => %w{options},
        :rts      => /^\s+/,
        :match    => /^(?:(.+) )?(\d+) (\d+) (\d+)(?: (.+))?$/

    def dir_perm
        # Determine correct permission for created directory and file
        # we can afford more restrictive permissions when the user is known
        if target
            if user
                0700
            else
                0755
            end
        end
    end

    def file_perm
        if target
            if user
                0600
            else
                0644
            end
        end
    end

    def target
        @resource.should(:target) || File.expand_path("~%s/.ssh/authorized_keys" % user)
    end

    def user
        @resource.should(:user)
    end

    def flush
        raise Puppet::Error, "Cannot write SSH authorized keys without user" unless user
        raise Puppet::Error, "User '#{user}' does not exist"                 unless uid = Puppet::Util.uid(user)
        unless File.exist?(dir = File.dirname(target))
            Puppet.debug "Creating #{dir}"
            Dir.mkdir(dir, dir_perm)
            File.chown(uid, nil, dir)
        end
        Puppet::Util::SUIDManager.asuser(user) { super }
        File.chown(uid, nil, target)
        File.chmod(file_perm, target)
    end

    # parse sshv2 option strings, wich is a comma separated list of
    # either key="values" elements or bare-word elements
    def self.parse_options(options)
        result = []
        scanner = StringScanner.new(options)
        while !scanner.eos?
            scanner.skip(/[ \t]*/)
            # scan a long option
            if out = scanner.scan(/[-a-z0-9A-Z_]+=\".*?\"/) or out = scanner.scan(/[-a-z0-9A-Z_]+/)
                result << out
            else
                # found an unscannable token, let's abort
                break
            end
            # eat a comma
            scanner.skip(/[ \t]*,[ \t]*/)
        end
        result
    end
end

