#!/usr/bin/ruby -w

#--------------------
# the puppet client
#
# $Id$


require 'puppet'
require 'openssl'

module Puppet
module SSLCertificates
    def self.mkdir(dir)
        # this is all a bunch of stupid hackery
        unless FileTest.exists?(dir)
            comp = Puppet::Type::Component.create(
                :name => "certdir creation"
            )
            path = ['']

            dir.split(File::SEPARATOR).each { |d|
                path << d
                if FileTest.exists?(File.join(path))
                    unless FileTest.directory?(File.join(path))
                        raise "%s exists but is not a directory" % File.join(path)
                    end
                else
                    obj = Puppet::Type.type(:file).create(
                        :name => File.join(path),
                        :mode => "750",
                        :create => "directory"
                    )

                    comp.push obj
                end
            }
            trans = comp.evaluate
            trans.evaluate
        end

        Puppet::Type.allclear
    end

    #def self.mkcert(type, name, days, issuercert, issuername, serial, publickey)
    def self.mkcert(hash)
        [:type, :name, :days, :issuer, :serial, :publickey].each { |param|
            unless hash.include?(param)
                raise ArgumentError, "mkcert called without %s" % param
            end
        }

        cert = OpenSSL::X509::Certificate.new
        from = Time.now

        cert.subject = hash[:name]
        if hash[:issuer]
            cert.issuer = hash[:issuer].subject
        else
            # we're a self-signed cert
            cert.issuer = hash[:name]
        end
        cert.not_before = from
        cert.not_after = from + (hash[:days] * 24 * 60 * 60)
        cert.version = 2 # X509v3

        cert.public_key = hash[:publickey]
        cert.serial = hash[:serial]

        basic_constraint = nil
        key_usage = nil
        ext_key_usage = nil

        ef = OpenSSL::X509::ExtensionFactory.new

        ef.subject_certificate = cert

        if hash[:issuer]
            ef.issuer_certificate = hash[:issuer]
        else
            ef.issuer_certificate = cert
        end

        ex = []
        case hash[:type]
        when :ca:
            basic_constraint = "CA:TRUE"
            key_usage = %w{cRLSign keyCertSign}
        when :terminalsubca:
            basic_constraint = "CA:TRUE,pathlen:0"
            key_usage = %w{cRLSign keyCertSign}
        when :server:
            basic_constraint = "CA:FALSE"
            key_usage = %w{digitalSignature keyEncipherment}
        ext_key_usage = %w{serverAuth clientAuth}
        when :ocsp:
            basic_constraint = "CA:FALSE"
            key_usage = %w{nonRepudiation digitalSignature}
        ext_key_usage = %w{serverAuth OCSPSigning}
        when :client:
            basic_constraint = "CA:FALSE"
            key_usage = %w{nonRepudiation digitalSignature keyEncipherment}
        ext_key_usage = %w{clientAuth emailProtection}
            ex << ef.create_extension("nsCertType", "client,email")
        else
            raise Puppet::Error, "unknown cert type '%s'" % hash[:type]
        end

        ex << ef.create_extension("nsComment",
                                  "Puppet Ruby/OpenSSL Generated Certificate")
        ex << ef.create_extension("basicConstraints", basic_constraint, true)
        ex << ef.create_extension("subjectKeyIdentifier", "hash")

        if key_usage
          ex << ef.create_extension("keyUsage", key_usage.join(","))
        end
        if ext_key_usage
          ex << ef.create_extension("extendedKeyUsage", ext_key_usage.join(","))
        end

        #if @ca_config[:cdp_location] then
        #  ex << ef.create_extension("crlDistributionPoints",
        #                            @ca_config[:cdp_location])
        #end

        #if @ca_config[:ocsp_location] then
        #  ex << ef.create_extension("authorityInfoAccess",
        #                            "OCSP;" << @ca_config[:ocsp_location])
        #end
        cert.extensions = ex

        # for some reason this _must_ be the last extension added
        if hash[:type] == :ca
            ex << ef.create_extension("authorityKeyIdentifier",
                                      "keyid:always,issuer:always")
        end

        return cert
    end

    def self.mkhash(dir, cert, certfile)
        hash = "%x" % cert.issuer.hash
        hashpath = nil
        10.times { |i|
            path = File.join(dir, "%s.%s" % [hash, i])
            if FileTest.exists?(path)
                if FileTest.symlink?(path)
                    dest = File.readlink(path)
                    if dest == certfile
                        # the correct link already exists
                        hashpath = path
                        break
                    else
                        next
                    end
                else
                    next
                end
            end

            File.symlink(certfile, path)

            hashpath = path
            break
        }

        return hashpath
    end



    class CA
        attr_accessor :keyfile, :file, :config, :dir, :cert

        @@params = [
            :certdir,
            :publickeydir,
            :privatekeydir,
            :cadir,
            :cakey,
            :cacert,
            :capass,
            :capub,
            :csrdir,
            :signeddir,
            :serial,
            :privatedir,
            :ca_crl_days,
            :ca_days,
            :ca_md,
            :req_bits,
            :keylength,
            :autosign
        ]

        @@defaults = {
            :certdir        => [:ssldir,         "certs"],
            :publickeydir   => [:ssldir,         "public_keys"],
            :privatekeydir  => [:ssldir,         "private_keys"],
            :cadir          => [:ssldir,         "ca"],
            :cacert         => [:cadir,          "ca_crt.pem"],
            :cakey          => [:cadir,          "ca_key.pem"],
            :capub          => [:cadir,          "ca_pub.pem"],
            :csrdir         => [:cadir,          "requests"],
            :signeddir      => [:cadir,          "signed"],
            :capass         => [:cadir,          "ca.pass"],
            :serial         => [:cadir,          "serial"],
            :privatedir     => [:ssldir,         "private"],
            :passfile       => [:privatedir,     "password"],
            :autosign       => [:puppetconf,     "autosign.conf"],
            :ca_crl_days    => 365,
            :ca_days        => 1825,
            :ca_md          => "md5",
            :req_bits       => 2048,
            :keylength      => 1024,
        }

        @@params.each { |param|
            Puppet.setdefault(param,@@defaults[param])
        }

        def certfile
            @config[:cacert]
        end

        def host2csrfile(hostname)
            File.join(Puppet[:csrdir], [hostname, "pem"].join("."))
        end

        # this stores signed certs in a directory unrelated to 
        # normal client certs
        def host2certfile(hostname)
            File.join(Puppet[:signeddir], [hostname, "pem"].join("."))
        end

        def thing2name(thing)
            thing.subject.to_a.find { |ary|
                ary[0] == "CN"
            }[1]
        end

        def initialize(hash = {})
            self.setconfig(hash)

            self.getcert
            unless FileTest.exists?(@config[:serial])
                File.open(@config[:serial], "w") { |f|
                    f << "%04X" % 1
                }
            end

            if Puppet[:capass] and ! FileTest.exists?(Puppet[:capass])
                self.genpass
            end
        end

        def genpass
            pass = ""
            20.times { pass += (rand(74) + 48).chr }

            unless @config[:capass]
                raise "No passfile"
            end
            Puppet::SSLCertificates.mkdir(File.dirname(@config[:capass]))
            File.open(@config[:capass], "w", 0600) { |f| f.print pass }
            return pass
        end

        def getcert
            if FileTest.exists?(@config[:cacert])
                @cert = OpenSSL::X509::Certificate.new(
                    File.read(@config[:cacert])
                )
            else
                self.mkrootcert
            end
        end

        def getclientcsr(host)
            csrfile = host2csrfile(host)
            unless File.exists?(csrfile)
                return nil
            end

            return OpenSSL::X509::Request.new(File.read(csrfile))
        end

        def getclientcert(host)
            certfile = host2certfile(host)
            unless File.exists?(certfile)
                return [nil, nil]
            end

            return [OpenSSL::X509::Certificate.new(File.read(certfile)), @cert]
        end

        def list
            return Dir.entries(Puppet[:csrdir]).reject { |file|
                file =~ /^\.+$/
            }.collect { |file|
                file.sub(/\.pem$/, '')
            }
        end

        def mkrootcert
            cert = Certificate.new(
                :name => "CAcert",
                :cert => @config[:cacert],
                :encrypt => @config[:passfile],
                :key => @config[:cakey],
                :selfsign => true,
                :length => 1825,
                :type => :ca
            )
            @cert = cert.mkselfsigned
            File.open(@config[:cacert], "w", 0660) { |f|
                f.puts @cert.to_pem
            }
            @key = cert.key
            return cert
        end

        def removeclientcsr(host)
            csrfile = host2csrfile(host)
            unless File.exists?(csrfile)
                raise Puppet::Error, "No certificate request for %s" % host
            end

            File.unlink(csrfile)
        end

        def setconfig(hash)
            @config = {}
            @@params.each { |param|
                if hash.include?(param)
                    begin
                    @config[param] = hash[param]
                    Puppet[param] = hash[param]
                    hash.delete(param)
                    rescue => detail
                        puts detail
                        exit
                    end
                else
                    begin
                    @config[param] = Puppet[param]
                    rescue => detail
                        puts detail
                        exit
                    end
                end
            }

            if hash.include?(:password)
                @config[:password] = hash[:password]
                hash.delete(:password)
            end

            if hash.length > 0
                raise ArgumentError, "Unknown parameters %s" % hash.keys.join(",")
            end

            [:cadir, :csrdir, :signeddir].each { |dir|
                unless @config[dir]
                    raise "%s is undefined" % dir
                end
                unless FileTest.exists?(@config[dir])
                    Puppet::SSLCertificates.mkdir(@config[dir])
                end
            }
        end

        def sign(csr)
            unless csr.is_a?(OpenSSL::X509::Request)
                raise Puppet::Error,
                    "CA#sign only accepts OpenSSL::X509::Request objects, not %s" %
                    csr.class
            end

            unless csr.verify(csr.public_key)
                raise Puppet::Error, "CSR sign verification failed"
            end

            # i should probably check key length...

            # read the ca cert in
            cacert = OpenSSL::X509::Certificate.new(
                File.read(@config[:cacert])
            )

            cakey = nil
            if @config[:password]
                cakey = OpenSSL::PKey::RSA.new(
                    File.read(@config[:cakey]), @config[:password]
                )
            else
                cakey = OpenSSL::PKey::RSA.new(
                    File.read(@config[:cakey])
                )
            end

            unless cacert.check_private_key(cakey)
                raise Puppet::Error, "CA Certificate is invalid"
            end

            serial = File.read(@config[:serial]).chomp.hex
            newcert = SSLCertificates.mkcert(
                :type => :server,
                :name => csr.subject,
                :days => @config[:ca_days],
                :issuer => cacert,
                :serial => serial,
                :publickey => csr.public_key
            )

            # increment the serial
            File.open(@config[:serial], "w") { |f|
                f << "%04X" % (serial + 1)
            }

            newcert.sign(cakey, OpenSSL::Digest::SHA1.new)

            self.storeclientcert(newcert)

            return [newcert, cacert]
        end

        def storeclientcsr(csr)
            host = thing2name(csr)

            csrfile = host2csrfile(host)
            if File.exists?(csrfile)
                raise Puppet::Error, "Certificate request for %s already exists" % host
            end

            File.open(csrfile, "w", 0660) { |f|
                f.print csr.to_pem
            }
        end

        def storeclientcert(cert)
            host = thing2name(cert)

            certfile = host2certfile(host)
            if File.exists?(certfile)
                Puppet.notice "Overwriting signed certificate %s for %s" %
                    [certfile, host]
            end

            File.open(certfile, "w", 0660) { |f|
                f.print cert.to_pem
            }
        end

    end

    class Certificate
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
                raise "You must specify the common name for the certificate"
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
                Puppet::SSLCertificates.mkdir(@dir)
            end

            unless @certfile =~ /\.pem$/
                @certfile += ".pem"
            end
            @keyfile = hash[:key] || File.join(
                Puppet[:privatekeydir], [@name,"pem"].join(".")
            )
            unless FileTest.directory?(@dir)
                Puppet::SSLCertificates.mkdir(@dir)
            end

            [@keyfile].each { |file|
                dir = File.dirname(file)

                unless FileTest.directory?(dir)
                    Puppet::SSLCertificates.mkdir(dir)
                end
            }

            @days = hash[:length] || 365
            @selfsign = hash[:selfsign] || false
            @encrypt = hash[:encrypt] || false
            @replace = hash[:replace] || false
            @issuer = hash[:issuer] || nil
            
            if hash.include?(:type)
                case hash[:type] 
                when :ca, :client, :server: @type = hash[:type]
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
                    raise ":encrypt must be a path to a pass phrase file"
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
                :days => @days,
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
end
end
