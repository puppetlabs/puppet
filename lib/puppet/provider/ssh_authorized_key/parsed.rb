require 'puppet/provider/parsedfile'


      Puppet::Type.type(:ssh_authorized_key).provide(
        :parsed,
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
    0700
  end

  def file_perm
    0600
  end

  def user
    uid = File.stat(target).uid
    Etc.getpwuid(uid).name
  end

  def flush
    raise Puppet::Error, "Cannot write SSH authorized keys without user"    unless @resource.should(:user)
    raise Puppet::Error, "User '#{@resource.should(:user)}' does not exist" unless uid = Puppet::Util.uid(@resource.should(:user))
    unless File.exist?(dir = File.dirname(target))
      Puppet.debug "Creating #{dir}"
      Dir.mkdir(dir, dir_perm)
      File.chown(uid, nil, dir)
    end

    # ParsedFile usually calls backup_target much later in the flush process,
    # but our SUID makes that fail to open filebucket files for writing.
    # Fortunately, there's already logic to make sure it only ever happens once,
    # so calling it here supresses the later attempt by our superclass's flush method.
    self.class.backup_target(target)

    Puppet::Util::SUIDManager.asuser(@resource.should(:user)) { super }
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

