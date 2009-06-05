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
            if FileTest.exists?(file)
                File.unlink(file)
            end
        }

        if defined? @hash and @hash
            if FileTest.symlink?(@hash)
                File.unlink(@hash)
            end
        end
    end

    def exists?
        return FileTest.exists?(@certfile)
    end

    def getkey
        unless FileTest.exists?(@keyfile)
            self.mkkey()
        end
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
        unless hash.include?(:name)
            raise Puppet::Error, "You must specify the common name for the certificate"
        end
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

        unless FileTest.directory?(@dir)
            Puppet.recmkdir(@dir)
        end

        unless @certfile =~ /\.pem$/
            @certfile += ".pem"
        end
        @keyfile = hash[:key] || File.join(
            Puppet[:privatekeydir], [@name,"pem"].join(".")
        )
        unless FileTest.directory?(@dir)
            Puppet.recmkdir(@dir)
        end

        [@keyfile].each { |file|
            dir = File.dirname(file)

            unless FileTest.directory?(dir)
                Puppet.recmkdir(dir)
            end
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
                raise "Invalid Cert type %s" % hash[:type]
            end
        else
            @type = :client
        end

        @params = {:name => @name}
        [:state, :country, :email, :org, :ou].each { |param|
            if hash.include?(param)
                @params[param] = hash[param]
            end
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

        if hash.include?(:selfsign)
            @selfsign = hash[:selfsign]
        else
            @selfsign = false
        end
    end

    # this only works for servers, not for users
    def mkcsr
        unless defined? @key and @key
            self.getkey
        end

        name = OpenSSL::X509::Name.new self.subject

        @csr = OpenSSL::X509::Request.new
        @csr.version = 0
        @csr.subject = name
        @csr.public_key = @key.public_key
        @csr.sign(@key, OpenSSL::Digest::SHA1.new)

        #File.open(@csrfile, "w") { |f|
        #    f << @csr.to_pem
        #}

        unless @csr.verify(@key.public_key)
            raise Puppet::Error, "CSR sign verification failed"
        end

        return @csr
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
            #passwdproc = proc { @password }
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
        unless defined? @key and @key
            self.getkey
        end

        if defined? @cert and @cert
            raise Puppet::Error, "Cannot replace existing certificate"
        end

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

        return @cert
    end

    def subject(string = false)
        subj = @@params2names.collect { |param, name|
            if @params.include?(param)
               [name, @params[param]]
            end
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
        if defined? @cacert
            files[@cacertfile] = @cacert
        end

        files.each { |file,thing|
            if defined? thing and thing
                if FileTest.exists?(file)
                    next
                end

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

        if defined? @cacert
            SSLCertificates.mkhash(Puppet[:certdir], @cacert, @cacertfile)
        end
    end
end

