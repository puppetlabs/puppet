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
        # As path expansion had to be moved in the provider, we cannot generate new file
        # resources and thus have to chown and chmod here. It smells hackish.

        # Create target's parent directory if nonexistant
        if target
            dir = File.dirname(target)
            if not File.exist? dir
                Puppet.debug("Creating directory %s which did not exist" % dir)
                Dir.mkdir(dir, dir_perm)
            end
        end

        # Generate the file
        super

        # Ensure correct permissions
        if target and user
            uid = Puppet::Util.uid(user)

            if uid
                File.chown(uid, nil, dir)
                File.chown(uid, nil, target)
            else
                raise Puppet::Error, "Specified user does not exist"
            end
        end

        if target
            File.chmod(file_perm, target)
        end
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

