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
            comp = Puppet::Type::Component.new(
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
                    obj = Puppet::Type.type(:file).new(
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
        cert = ::OpenSSL::X509::Certificate.new
        from = Time.now

        cert.subject = hash[:name]
        if hash[:issuer]
            cert.issuer = hash[:issuer].subject
        else
            cert.issuer = cert.subject
        end
        cert.not_before = from
        cert.not_after = from + (hash[:days] * 24 * 60 * 60)
        cert.version = 2 # X509v3

        cert.public_key = hash[:publickey]
        cert.serial = hash[:serial]

        basic_constraint = nil
        key_usage = []
        ext_key_usage = []

        case hash[:type]
        when :ca:
            basic_constraint = "CA:TRUE"
            key_usage.push %w{cRLSign keyCertSign}
        when :terminalsubca:
            basic_constraint = "CA:TRUE,pathlen:0"
            key_usage %w{cRLSign keyCertSign}
        when :server:
            basic_constraint = "CA:FALSE"
            key_usage << %w{digitalSignature keyEncipherment}
        ext_key_usage << "serverAuth"
        when :ocsp:
            basic_constraint = "CA:FALSE"
            key_usage << %w{nonRepudiation digitalSignature}
        ext_key_usage << %w{serverAuth OCSPSigning}
        when :client:
            basic_constraint = "CA:FALSE"
            key_usage << %w{nonRepudiation digitalSignature keyEncipherment}
        ext_key_usage << %w{clientAuth emailProtection}
        else
            raise "unknonwn cert type '%s'" % hash[:type]
        end

        key_usage.flatten!
        ext_key_usage.flatten!

        ef = ::OpenSSL::X509::ExtensionFactory.new

        if hash[:issuer]
            ef.issuer_certificate = hash[:issuer]
        else
            ef.issuer_certificate = cert
        end

        ef.subject_certificate = cert

        ex = []
        ex << ef.create_extension("basicConstraints", basic_constraint, true)
        ex << ef.create_extension("nsComment",
                                  "Ruby/OpenSSL Generated Certificate")
        ex << ef.create_extension("subjectKeyIdentifier", "hash")
        #ex << ef.create_extension("nsCertType", "client,email")
        unless key_usage.empty? then
          ex << ef.create_extension("keyUsage", key_usage.join(","))
        end
        #ex << ef.create_extension("authorityKeyIdentifier",
        #                          "keyid:always,issuer:always")
        #ex << ef.create_extension("authorityKeyIdentifier", "keyid:always")
        unless ext_key_usage.empty? then
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

        #cmd = "#{ossl} req -nodes -new -x509 -keyout %s -out %s -config %s" %
        #    [@key, certfile, Puppet::SSLCertificates.config]

        # write the cert out
        #File.open(certfile, "w") {  |f| f << cert.to_pem }

        return cert
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
            :autosign       => [:ssldir,         "autosign"],
            :ca_crl_days    => 365,
            :ca_days        => 1825,
            :ca_md          => "md5",
            :req_bits       => 2048,
            :keylength      => 1024,
        }

        @@params.each { |param|
            Puppet.setdefault(param,@@defaults[param])
        }

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
                    f << "%04X" % 0
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
                return nil
            end

            return OpenSSL::X509::Certificate.new(File.read(certfile))
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
                :length => 1825
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
                raise "CA#sign only accepts OpenSSL::X509::Request objects, not %s" %
                    csr.class
            end

            unless csr.verify(csr.public_key)
                raise "CSR sign verification failed"
            end

            # i should probably check key length...

            # read the ca cert in
            cacert = ::OpenSSL::X509::Certificate.new(
                File.read(@config[:cacert])
            )

            ca_keypair = ::OpenSSL::PKey::RSA.new(
                File.read(@config[:cakey]), @config[:password]
            )

            serial = File.read(@config[:serial]).chomp.hex
            newcert = SSLCertificates.mkcert(
                :type => :server,
                :name => csr.subject,
                :days => @config[:ca_days],
                :issuer => cacert,
                :serial => serial,
                :publickey => ca_keypair.public_key
            )

            # increment the serial
            File.open(@config[:serial], "w") { |f|
                f << "%04X" % (serial + 1)
            }

            newcert.sign(ca_keypair, ::OpenSSL::Digest::SHA1.new)

            self.storeclientcert(newcert)

            return newcert
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
                Puppet.notice "Overwriting signed certificate for %s" % host
            end

            File.open(certfile, "w", 0660) { |f|
                f.print cert.to_pem
            }
        end

    end

    class Certificate
        attr_accessor :certfile, :keyfile, :name, :dir, :hash, :type
        attr_accessor :key, :cert, :csr

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
            ::OpenSSL::X509::Name.new self.subject
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
                @key = ::OpenSSL::PKey::RSA.new(
                    File.read(@keyfile),
                    @password
                )
            else
                @key = ::OpenSSL::PKey::RSA.new(
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

            name = ::OpenSSL::X509::Name.new self.subject

            @csr = ::OpenSSL::X509::Request.new
            @csr.version = 0
            @csr.subject = name
            @csr.public_key = @key.public_key
            @csr.sign(@key, ::OpenSSL::Digest::MD5.new)

            #File.open(@csrfile, "w") { |f|
            #    f << @csr.to_pem
            #}

            return @csr
        end

        def mkhash
            hash = "%x" % @cert.issuer.hash
            path = nil
            10.times { |i|
                path = File.join(@dir, "%s.%s" % [hash, i])
                if FileTest.exists?(path)
                    if FileTest.symlink?(path)
                        dest = File.readlink(path)
                        if dest == @certfile
                            # the correct link already exists
                            puts "hash already exists"
                            @hash = path
                            return
                        else
                            next
                        end
                    else
                        next
                    end
                end

                File.symlink(@certfile, path)

                @hash = path
                break
            }

            return path
        end

        def mkkey
            # @key is the file

            @key = ::OpenSSL::PKey::RSA.new 1024

            if @password
                #passwdproc = proc { @password }
                keytext = @key.export(
                    ::OpenSSL::Cipher::DES.new(:EDE3, :CBC),
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

            @cert = SSLCertificates.mkcert(
                :type => :server,
                :name => self.certname,
                :days => @days,
                :issuer => nil,
                :serial => 0x0,
                :publickey => @key.public_key
            )

            @cert.sign(@key, ::OpenSSL::Digest::SHA1.new) if @selfsign
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

        def write
            files = {
                @certfile => @cert,
                @keyfile => @key,
            }
                #@csrfile => @csr

            files.each { |file,thing|
                if defined? thing and thing
                    if FileTest.exists?(file)
                        newtext = File.open(file) { |f| f.read }
                        if newtext != thing.to_pem
                            raise "Cannot replace existing %s" % thing.class
                        else
                            next
                        end
                    end

                    File.open(file, "w", 0660) { |f| f.print thing.to_pem }
                end
            }

            self.mkhash
        end
    end
end
end
