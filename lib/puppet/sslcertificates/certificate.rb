class Puppet::SSLCertificates::Certificate
  SSLCertificates = Puppet::SSLCertificates

  attr_accessor :certfile, :keyfile, :name, :dir, :hash, :type
  attr_accessor :key, :cert, :csr, :cacert

  @@params2names = {
    :name       => "CN",
    :state      => "ST",
    :country    => "C",
    :email      => "emailAddress",
    :org        => "O",
    :city       => "L",
    :ou         => "OU"
  }

  def certname
    OpenSSL::X509::Name.new self.subject
  end

  def delete
    [@certfile,@keyfile].each { |file|
      File.unlink(file) if FileTest.exists?(file)
    }

    if @hash
      File.unlink(@hash) if FileTest.symlink?(@hash)
    end
  end

  def exists?
    FileTest.exists?(@certfile)
  end

  def getkey
    self.mkkey unless FileTest.exists?(@keyfile)
    if @password

      @key = OpenSSL::PKey::RSA.new(

        File.read(@keyfile),

        @password
      )
    else
      @key = OpenSSL::PKey::RSA.new(
        File.read(@keyfile)
      )
    end
  end

  def initialize(hash)
    raise Puppet::Error, "You must specify the common name for the certificate" unless hash.include?(:name)
    @name = hash[:name]

    # init a few variables
    @cert = @key = @csr = nil

    if hash.include?(:cert)
      @certfile = hash[:cert]
      @dir = File.dirname(@certfile)
    else
      @dir = hash[:dir] || Puppet[:certdir]
      @certfile = File.join(@dir, @name)
    end

    @cacertfile ||= File.join(Puppet[:certdir], "ca.pem")

    Puppet.recmkdir(@dir) unless FileTest.directory?(@dir)

    unless @certfile =~ /\.pem$/
      @certfile += ".pem"
    end
    @keyfile = hash[:key] || File.join(
      Puppet[:privatekeydir], [@name,"pem"].join(".")
    )
    Puppet.recmkdir(@dir) unless FileTest.directory?(@dir)

    [@keyfile].each { |file|
      dir = File.dirname(file)

      Puppet.recmkdir(dir) unless FileTest.directory?(dir)
    }

    @ttl = hash[:ttl] || 365 * 24 * 60 * 60
    @selfsign = hash[:selfsign] || false
    @encrypt = hash[:encrypt] || false
    @replace = hash[:replace] || false
    @issuer = hash[:issuer] || nil

    if hash.include?(:type)
      case hash[:type]
      when :ca, :client, :server; @type = hash[:type]
      else
        raise "Invalid Cert type #{hash[:type]}"
      end
    else
      @type = :client
    end

    @params = {:name => @name}
    [:state, :country, :email, :org, :ou].each { |param|
      @params[param] = hash[param] if hash.include?(param)
    }

    if @encrypt
      if @encrypt =~ /^\//
        File.open(@encrypt) { |f|
          @password = f.read.chomp
        }
      else
        raise Puppet::Error, ":encrypt must be a path to a pass phrase file"
      end
    else
      @password = nil
    end

    @selfsign = hash.include?(:selfsign) && hash[:selfsign]
  end

  # this only works for servers, not for users
  def mkcsr
    self.getkey unless @key

    name = OpenSSL::X509::Name.new self.subject

    @csr = OpenSSL::X509::Request.new
    @csr.version = 0
    @csr.subject = name
    @csr.public_key = @key.public_key
    @csr.sign(@key, OpenSSL::Digest::SHA1.new)

    #File.open(@csrfile, "w") { |f|
    #    f << @csr.to_pem
    #}

    raise Puppet::Error, "CSR sign verification failed" unless @csr.verify(@key.public_key)

    @csr
  end

  def mkkey
    # @key is the file

    @key = OpenSSL::PKey::RSA.new(1024)
#            { |p,n|
#                case p
#                when 0; Puppet.info "key info: ."  # BN_generate_prime
#                when 1; Puppet.info "key info: +"  # BN_generate_prime
#                when 2; Puppet.info "key info: *"  # searching good prime,
#                                          # n = #of try,
#                                          # but also data from BN_generate_prime
#                when 3; Puppet.info "key info: \n" # found good prime, n==0 - p, n==1 - q,
#                                          # but also data from BN_generate_prime
#                else;   Puppet.info "key info: *"  # BN_generate_prime
#                end
#            }

  if @password
  #        passwdproc = proc { @password }

    keytext = @key.export(

      OpenSSL::Cipher::DES.new(:EDE3, :CBC),

      @password
      )
      File.open(@keyfile, "w", 0400) { |f|
        f << keytext
      }
    else
      File.open(@keyfile, "w", 0400) { |f|
        f << @key.to_pem
      }
    end

    #cmd = "#{ossl} genrsa -out #{@key} 1024"
  end

  def mkselfsigned
    self.getkey unless @key

    raise Puppet::Error, "Cannot replace existing certificate" if @cert

    args = {
      :name => self.certname,
      :ttl => @ttl,
      :issuer => nil,
      :serial => 0x0,
      :publickey => @key.public_key
    }
    if @type
      args[:type] = @type
    else
      args[:type] = :server
    end
    @cert = SSLCertificates.mkcert(args)

    @cert.sign(@key, OpenSSL::Digest::SHA1.new) if @selfsign

    @cert
  end

  def subject(string = false)
    subj = @@params2names.collect { |param, name|
      [name, @params[param]] if @params.include?(param)
    }.reject { |ary| ary.nil? }

    if string
      return "/" + subj.collect { |ary|
        "%s=%s" % ary
      }.join("/") + "/"
    else
      return subj
    end
  end

  # verify that we can track down the cert chain or whatever
  def verify
    "openssl verify -verbose -CAfile /home/luke/.puppet/ssl/certs/ca.pem -purpose sslserver culain.madstop.com.pem"
  end

  def write
    files = {
      @certfile => @cert,
      @keyfile => @key,
    }
    files[@cacertfile] = @cacert if defined?(@cacert)

    files.each { |file,thing|
      if thing
        next if FileTest.exists?(file)

        text = nil

        if thing.is_a?(OpenSSL::PKey::RSA) and @password

          text = thing.export(

            OpenSSL::Cipher::DES.new(:EDE3, :CBC),

            @password
          )
        else
          text = thing.to_pem
        end

        File.open(file, "w", 0660) { |f| f.print text }
      end
    }

    SSLCertificates.mkhash(Puppet[:certdir], @cacert, @cacertfile) if defined?(@cacert)
  end
end

