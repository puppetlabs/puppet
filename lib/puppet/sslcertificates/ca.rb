class Puppet::SSLCertificates::CA
    Certificate = Puppet::SSLCertificates::Certificate
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
        newcert = Puppet::SSLCertificates.mkcert(
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

# $Id$
