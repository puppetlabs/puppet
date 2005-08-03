#!/usr/bin/ruby -w

#--------------------
# the puppet client
#
# $Id$


require 'puppet'
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
            raise output
        end
        return output
    end

    def self.findopenssl
        if defined? @@openssl
            return @@openssl
        end
        @@openssl = %x{which openssl}.chomp

        if @@openssl == ""
            $stderr.puts "Could not find openssl in path"
            exit(12)
        end

        return @@openssl
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
            
            serial = @config["local_ca"]["serial"].value.chomp
            unless FileTest.exists?(serial)
                unless FileTest.exists?(File.dirname(serial))
                    Puppet::OpenSSL.mkdir(File.dirname(serial))
                end
                File.open(serial, "w", 0600) { |f| f.puts "01" }
            end
            
            database = @config["local_ca"]["database"].value.chomp
            unless FileTest.exists?(database)
                unless FileTest.exists?(File.dirname(database))
                    Puppet::OpenSSL.mkdir(File.dirname(database))
                end
                File.open(database, "w", 0600) { |f| f.print "" }
            end
            
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
                self.genpass
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
                return self.mkcert
            end
        end

        def getconfig
            if FileTest.exists?(@file)
                return Puppet::OpenSSL::Config.new(@file)
            else
                return self.mkconfig
            end
        end

        def mkcert
            #"openssl req -x509 -newkey rsa -out cacert.pem -outform PEM -days 1825"
            cert = Certificate.new(
                :name => "CAcert",
                :cert => @certfile,
                :encrypt => @passfile,
                :key => @keyfile,
                :length => 1825
            )

            cert.mkselfsigned
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

            ossl = Puppet::OpenSSL.findopenssl
            sign = [ossl]
            sign << "ca" 
            sign << "-batch" 
            sign << ["-config", self.file]
            sign << ["-passin", "file:%s" % @passfile]
            sign << ["-out", cert.cert]
            sign << ["-infiles", cert.csr]

            Puppet::OpenSSL.exec(sign.flatten.join(" "))
            # and then verify it

            #verify = "%s verify -CAfile %s %s" %
            #    [ossl, @cert, cert.cert]
            verify = "%s verify %s" %
                [ossl, cert.cert]

            Puppet::OpenSSL.exec(verify)
            #openssl ca -config ca.config -out $CERT -infiles $CSR
            #echo "CA verifying: $CERT <-> CA cert"
            #openssl verify -CAfile ca.crt $CERT
        end
    end

    class Certificate
        attr_accessor :cert, :key, :name, :dir, :hash, :csr

        @@params2names = {
            :name       => "CN",
            :state      => "ST",
            :country    => "C",
            :email      => "emailAddress",
            :org        => "O",
            :city       => "L",
            :ou         => "OU"
        }

        def delete
            [@cert,@key,@csr].each { |file|
                FileTest.exists?(file) and File.unlink(file)
            }

            if @hash
                if FileTest.symlink?(@hash)
                    File.unlink(@hash)
                end
            end
        end

        def exists?
            FileTest.exists?(@cert)
        end

        def initialize(hash)
            unless hash.include?(:name)
                raise "You must specify the common name for the certificate"
            end
            @name = hash[:name]

            if hash.include?(:cert)
                @cert = hash[:cert]
                @dir = File.dirname(@cert)
            else
                @dir = hash[:dir]
                unless hash.include?(:dir)
                    raise "You must specify the directory in which to store certs"
                end
                @cert = File.join(@dir, @name)
            end

            unless @cert =~ /\.pem$/
                @cert += ".pem"
            end
            @key = hash[:key] || File.join(@dir, @name + "_key.pem")
            @csr = hash[:csr] || File.join(@dir, @name + "_csr.pem")
            @days = hash[:length] || 365
            @selfsign = hash[:selfsign] || false
            @encrypt = hash[:encrypt] || false
            @replace = hash[:replace] || false

            @params = {:name => @name}
            [:state, :country, :email, :org, :ou].each { |param|
                if hash.include?(param)
                    @params[param] = hash[param]
                end
            }

            if @encrypt
                unless @encrypt =~ /^\//
                    raise ":encrypt must be a path to a pass phrase file"
                end
            end

            if hash.include?(:selfsign)
                @selfsign = hash[:selfsign]
            else
                @selfsign = false
            end

            @ossl = Puppet::OpenSSL.findopenssl
        end

        #def mkcert
        #    cmd = "#{ossl} req -nodes -new -x509 -keyout %s -out %s -config %s" %
        #        [@key, @cert, Puppet::OpenSSL.config]
        #end

        def mkcsr
            #cmd = "#{ossl} req -new -key #{@key} -out #{@csr}"
            #self.class.exec(exec)
            cmd = [@ossl, "req"]
            cmd << "-batch"
            cmd << "-new"
            cmd << ["-newkey", "rsa:1024"]
            cmd << ["-subj", self.subject]
            cmd << ["-keyout", @key]
            cmd << ["-out", @csr]

            if @encrypt
                cmd << ["-passout", "file:" + @encrypt]
            else
                cmd << "-nodes"
            end

            Puppet::OpenSSL.exec(cmd.flatten.join(" "))
        end

        def mkhash
            hash = Puppet::OpenSSL.exec("openssl x509 -noout -hash -in %s" % @cert).chomp
            10.times { |i|
                path = File.join(@dir, "%s.%s" % [hash, i])
                if FileTest.exists?(path)
                    if FileTest.symlink?(path)
                        dest = File.readlink(path)
                        if dest == @cert
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

                File.symlink(@cert, path)

                @hash = path
                break
            }
        end

        #def mkkey
        #    cmd = "#{ossl} genrsa -out #{@key} 1024"
        #end

        def mkselfsigned
            if self.exists?
                unless @replace
                    raise "Certificate exists"
                end
            end

            cmd = [@ossl, "req"]
            cmd << "-batch"
            cmd << ["-subj", self.subject]
            cmd << "-new"
            cmd << "-x509"
            cmd << ["-keyout", @key]
            cmd << ["-out", @cert]

            if @encrypt
                cmd << ["-passout", "file:" + @encrypt]
            else
                cmd << "-nodes"
            end

            Puppet::OpenSSL.exec(cmd.flatten.join(" "))
            self.mkhash
        end

        def subject
            subj = "/" + @@params2names.collect { |param, name|
                if @params.include?(param)
                    "%s=%s" % [name, @params[param]]
                end
            }.reject { |s| s.nil? }.join("/") + "/"
            return subj
        end
    end
end
end
