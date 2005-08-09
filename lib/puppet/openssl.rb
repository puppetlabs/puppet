#!/usr/bin/ruby -w

#--------------------
# the puppet client
#
# $Id$


require 'puppet'
require 'openssl'
require 'getoptlong'

module Puppet
module OpenSSL
    @@config = "/etc/ssl/openssl.cnf"

    def self.config=(config)
        @@config = config
    end

    def self.config
        return @@config
    end

    def self.exec(cmd)
        output = %x{#{cmd} 2>&1}

        #puts "\n\n%s\n\n" % cmd
        unless $? == 0
            puts cmd
            raise output
        end
        return output
    end

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


    class Config
        include Enumerable
        attr_accessor :path

        def [](name)
            @sectionhash[name]
        end

        def clear
            @sectionhash.clear
            @sectionary.clear
        end

        def each
            @sectionary.each { |section|
                yield section
            }
        end

        def initialize(path)
            @path = path

            @sectionhash = {}
            @sectionary = []

            # default to reading the config in
            if FileTest.exists?(@path)
                self.read
            end
        end

        def newsection(name)
            sect = Section.new(name)
            @sectionhash[sect.name] = sect
            @sectionary.push sect
            return sect
        end

        def read
            self.clear
            section = self.newsection(:HEAD)
            comments = ""
            File.open(@path) { |f|
                f.readlines.each { |line|
                    case line
                    when /^\s*#/: comments += line
                    when /^\[ (\w+) \]$/:
                        name = $1
                        section = self.newsection(name)
                    when /^(\w+)\s*=\s*([^#]+)(#.*)*$/
                        section.newparam($1, $2, comments)
                        comments = ""
                    when /^(\d+\.\w+)\s*=\s*([^#]+)(#.*)*$/
                        section.newparam($1, $2, comments)
                        comments = ""
                    when /^\s*$/: # nothing
                        comments += line
                    else
                        puts "Could not match line %s" % line.inspect
                    end
                }
            }
        end

        def to_s
            @sectionary.collect { |section|
                section.to_s
            }.join("\n") + "\n"
        end

        def write
            File.open(@path, "w") { |f|
                f.print self.to_s
            }
        end

        class Section
            include Enumerable
            attr_accessor :name

            def [](name)
                @paramhash[name]
            end

            def []=(name,value)
                if @paramhash.include?(name)
                    @paramhash[name] = value
                else
                    self.newparam(name, value)
                end
            end

            def each
                @paramary.each { |param|
                    yield param
                }
            end

            def include?(name)
                @paramhash.include?(name)
            end

            def initialize(name)
                @name = name

                @paramhash = {}
                @paramary = []
            end

            def newparam(name, value, comments = nil)
                if @paramhash.include?(name)
                    raise "%s already has a param %s" % [@name, name]
                end
                obj = Parameter.new(name, value, comments)
                @paramhash[name] = obj
                @paramary.push obj
            end

            def to_s
                str = ""
                unless @name == :HEAD
                    str += "[ #{@name} ]\n"
                end
                return str + (@paramary.collect { |param|
                    param.to_s
                }.join("\n"))
            end
        end

        class Parameter
            attr_accessor :name, :value, :comments

            def initialize(name, value, comments)
                @name = name
                @value = value.sub(/\s+$/,'')
                @comments = comments
            end

            def to_s
                if comments and comments != ""
                    return "%s%s = %s" % [@comments, @name, @value]
                else
                    return "%s = %s" % [@name, @value]
                end
            end
        end
    end

    class CA
        attr_accessor :keyfile, :file, :config, :dir, :cert

        @@DEFAULTCONF = %{#
# Default configuration to use  when one is not provided on the command line.
#
[ ca ]
default_ca  = local_ca

#
# Default location  of  directories  and files needed to generate
# certificates.
#
[ local_ca ]
certificate     = BASEDIR/cacert.pem
database        = BASEDIR/index.txt
new_certs_dir   = BASEDIR/certs
private_key     = BASEDIR/private/cakey.pem
serial          = BASEDIR/serial

#
# Default   expiration   and  encryption policies for certificates.
#
default_crl_days        = 365
default_days            = 1825
default_md              = md5

policy          = local_ca_policy
x509_extensions = local_ca_extensions

#
# Default policy to use  when generating server   certificates.  The following
# fields  must  be defined in the server certificate.
#
[ local_ca_policy ]
commonName              = supplied
stateOrProvinceName     = supplied
countryName             = supplied
emailAddress            = supplied
organizationName        = supplied
organizationalUnitName  = supplied

#
# x509 extensions to use when generating server certificates.
#
[ local_ca_extensions ]
subjectAltName          = DNS:altname.somewhere.com
basicConstraints        = CA:false
nsCertType              = server

#
# The   default   policy   to  use  when
# generating the root certificate.
#
[ req ]
default_bits    = 2048
default_keyfile = BASEDIR/private/cakey.pem
default_md      = md5

prompt                  = no
distinguished_name      = root_ca_distinguished_name
x509_extensions         = root_ca_extensions

#
# Root  Certificate  Authority   distin- guished name.  Change these fields to
# your local environment.
#
[ root_ca_distinguished_name ]
commonName              = Reductive Labs Root Certificate Authority
stateOrProvinceName     = Some State
countryName             = US
emailAddress            = root@somename.somewhere.com
organizationName        = Root Certificate Authority

[ root_ca_extensions ]
basicConstraints        = CA:true
}
        def init
            self.mkconfig
            self.mkcert
        end

        def initialize(hash)
            unless hash.include?(:dir)
                raise "You must specify the base directory for the CA"
            end
            @dir = hash[:dir]

            @file = hash[:file] || File.join(@dir, "ca.cnf")

            unless FileTest.exists?(@dir)
                Puppet::OpenSSL.mkdir(@dir)
            end

            @config = self.getconfig

            @certfile = @config["local_ca"]["certificate"].value.chomp
            @keyfile = @config["local_ca"]["private_key"].value.chomp

            certdir = @config["local_ca"]["new_certs_dir"].value.chomp
            Puppet::OpenSSL.mkdir(certdir)
            
            @serial = @config["local_ca"]["serial"].value.chomp
            unless FileTest.exists?(@serial)
                unless FileTest.exists?(File.dirname(@serial))
                    Puppet::OpenSSL.mkdir(File.dirname(@serial))
                end
                File.open(@serial, "w", 0600) { |f| f.puts "01" }
            end
            
            database = @config["local_ca"]["database"].value.chomp
            unless FileTest.exists?(database)
                unless FileTest.exists?(File.dirname(database))
                    Puppet::OpenSSL.mkdir(File.dirname(database))
                end
                File.open(database, "w", 0600) { |f| f.print "" }
            end

            @days = @config["local_ca"]["default_crl_days"].value.to_i || 365
            
            unless @certfile
                raise "could not retrieve cert path"
            end

            unless @keyfile
                raise "could not retrieve key file"
            end

            if hash.include?(:password)
                @password = hash[:password]
            else
                @passfile = hash[:passfile] || File.join(@dir, "private", "phrase")
                @password = self.genpass
            end

            @cert = self.getcert
        end

        def genpass
            pass = ""
            20.times { pass += (rand(74) + 48).chr }

            unless @passfile
                raise "No passfile"
            end
            Puppet::OpenSSL.mkdir(File.dirname(@passfile))
            File.open(@passfile, "w", 0600) { |f| f.print pass }
            return pass
        end

        def getcert
            if FileTest.exists?(@certfile)
                return Puppet::OpenSSL::Certificate.new(
                    :name => "CAcert",
                    :cert => @certfile,
                    :encrypt => @passfile,
                    :key => @keyfile
                )
            else
                return self.mkrootcert
            end
        end

        def getconfig
            if FileTest.exists?(@file)
                return Puppet::OpenSSL::Config.new(@file)
            else
                return self.mkconfig
            end
        end

        def mkrootcert
            cert = Certificate.new(
                :name => "CAcert",
                :cert => @certfile,
                :encrypt => @passfile,
                :key => @keyfile,
                :selfsign => true,
                :length => 1825
            )
            @cert = cert.mkselfsigned
            @key = cert.key

            return cert
        end

        def mkconfig
            File.open(@file, "w") { |f| f.print @@DEFAULTCONF }

            config = Puppet::OpenSSL::Config.new(@file)

            config.each { |section|
                section.each { |param|
                    value = param.value.sub(/BASEDIR/, @dir)
                    param.value = value
                }
            }

            config.write

            return config
        end

        def sign(cert)
            unless cert.is_a?(Puppet::OpenSSL::Certificate)
                raise "CA#sign only accepts Puppet::OpenSSL::Certificate objects"
            end

            csr = ::OpenSSL::X509::Request.new(
                File.read(cert.csrfile)
            )

            unless csr.verify(csr.public_key)
                raise "CSR sign verification failed"
            end

            # i should probably check key length...

            # read the ca cert in
            if cert.exists?
                raise "Cannot sign existing certificates"
            end

            cacert = ::OpenSSL::X509::Certificate.new(
                File.read(@certfile)
            )

            ca_keypair = ::OpenSSL::PKey::RSA.new(
                File.read(@keyfile), @password
            )

            serial = File.read(@serial).chomp.hex
            newcert = cert.mkcert(
                cacert, cacert.subject, serial, ca_keypair.public_key
            )

            # increment the serial
            File.open(@serial, "w") { |f|
                f << "%04X" % (serial + 1)
            }

            newcert.sign(ca_keypair, ::OpenSSL::Digest::SHA1.new)

            File.open(cert.certfile, "w", 0644) { |f|
                f << newcert.to_pem
            }
            return newcert
        end
    end

    class Certificate
        attr_accessor :certfile, :keyfile, :name, :dir, :hash, :csrfile, :type
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
            [@certfile,@keyfile,@csrfile].each { |file|
                if FileTest.exists?(file)
                    File.unlink(file)
                end
            }

            if @hash
                if FileTest.symlink?(@hash)
                    File.unlink(@hash)
                end
            end
        end

        def exists?
            FileTest.exists?(@certfile)
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

            if hash.include?(:cert)
                @certfile = hash[:cert]
                @dir = File.dirname(@certfile)
            else
                @dir = hash[:dir]
                unless hash.include?(:dir)
                    raise "You must specify the directory in which to store certs"
                end
                @certfile = File.join(@dir, @name)
            end

            unless FileTest.directory?(@dir)
                Puppet::OpenSSL.mkdir(@dir)
            end

            unless @certfile =~ /\.pem$/
                @certfile += ".pem"
            end
            @keyfile = hash[:key] || File.join(@dir, @name + "_key.pem")
            @csrfile = hash[:csr] || File.join(@dir, @name + "_csr.pem")
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

        def mkcert(issuercert, issuername, serial, publickey)
            unless issuercert or @selfsign
                raise "Certs must either have an issuer or must be self-signed"
            end

            if self.exists?
                raise "Cannot replace existing certificate"
            end

            @cert = ::OpenSSL::X509::Certificate.new
            from = Time.now

            @cert.subject = self.certname
            @cert.issuer = issuername
            @cert.not_before = from
            @cert.not_after = from + (@days * 24 * 60 * 60)
            @cert.version = 2 # X509v3

            @cert.public_key = publickey
            @cert.serial = serial

            basic_constraint = nil
            key_usage = []
            ext_key_usage = []

            case @type
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
                raise "unknonwn cert type '%s'" % @type
            end

            key_usage.flatten!
            ext_key_usage.flatten!

            ef = ::OpenSSL::X509::ExtensionFactory.new

            if issuercert
                ef.issuer_certificate = issuercert
            else
                ef.issuer_certificate = @cert
            end

            ef.subject_certificate = @cert

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
            @cert.extensions = ex

            #cmd = "#{ossl} req -nodes -new -x509 -keyout %s -out %s -config %s" %
            #    [@key, @certfile, Puppet::OpenSSL.config]

            @cert.sign(@key, ::OpenSSL::Digest::SHA1.new) if @selfsign

            # write the cert out
            File.open(@certfile, "w") {  |f| f << @cert.to_pem }

            return @cert
        end

        # this only works for servers, not for users
        def mkcsr
            unless @key
                self.getkey
            end

            name = ::OpenSSL::X509::Name.new self.subject

            @csr = ::OpenSSL::X509::Request.new
            @csr.version = 0
            @csr.subject = name
            @csr.public_key = @key.public_key
            @csr.sign(@key, ::OpenSSL::Digest::MD5.new)

            File.open(@csrfile, "w") { |f|
                f << @csr.to_pem
            }

        end

        def mkhash
            hash = Puppet::OpenSSL.exec("openssl x509 -noout -hash -in %s" % @certfile).chomp
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
            unless @key
                self.getkey
            end

            self.mkcert(nil, self.certname, 0x0, @key.public_key)
#            self.mkhash
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
    end
end
end
