class Puppet::SSLCertificates::CA
    Certificate = Puppet::SSLCertificates::Certificate
    attr_accessor :keyfile, :file, :config, :dir, :cert

    Puppet.setdefaults(:ca,
        :cadir => {  :default => "$ssldir/ca",
            :mode => 0770,
            :desc => "The root directory for the certificate authority."
        },
        :cacert => { :default => "$cadir/ca_crt.pem",
            :mode => 0660,
            :desc => "The CA certificate."
        },
        :cakey => { :default => "$cadir/ca_key.pem",
            :mode => 0660,
            :desc => "The CA private key."
        },
        :capub => ["$cadir/ca_pub.pem", "The CA public key."],
        :caprivatedir => { :default => "$cadir/private",
            :mode => 0770,
            :desc => "Where the CA stores private certificate information."
        },
        :csrdir => ["$cadir/requests",
            "Where the CA stores certificate requests"],
        :signeddir => { :default => "$cadir/signed",
            :mode => 0770,
            :desc => "Where the CA stores signed certificates."
        },
        :capass => { :default => "$caprivatedir/ca.pass",
            :mode => 0660,
            :desc => "Where the CA stores the password for the private key"
        },
        :serial => ["$cadir/serial",
            "Where the serial number for certificates is stored."],
        :autosign => { :default => "$confdir/autosign.conf",
            :mode => 0640,
            :desc => "Whether to enable autosign.  Valid values are true (which
                autosigns any key request, and is a very bad idea), false (which
                never autosigns any key request), and the path to a file, which
                uses that configuration file to determine which keys to sign."},
        :ca_days => [1825, "How long a certificate should be valid."],
        :ca_md => ["md5", "The type of hash used in certificates."],
        :req_bits => [2048, "The bit length of the certificates."],
        :keylength => [1024, "The bit length of keys."]
    )

    #@@params.each { |param|
    #    Puppet.setdefault(param,@@defaults[param])
    #}

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
        Puppet.config.use(:puppet, :certificates, :ca)
        self.setconfig(hash)

        if Puppet[:capass]
            if FileTest.exists?(Puppet[:capass])
                #puts "Reading %s" % Puppet[:capass]
                #system "ls -al %s" % Puppet[:capass]
                #File.read Puppet[:capass]
                @config[:password] = self.getpass
            else
                # Don't create a password if the cert already exists
                unless FileTest.exists?(@config[:cacert])
                    @config[:password] = self.genpass
                end
            end
        end

        self.getcert
        unless FileTest.exists?(@config[:serial])
            File.open(@config[:serial], "w") { |f|
                f << "%04X" % 1
            }
        end
    end

    def genpass
        pass = ""
        20.times { pass += (rand(74) + 48).chr }

        # FIXME It's a hack that this still needs to be here :/
        unless FileTest.exists?(File.dirname(@config[:capass]))
            Puppet::Util.recmkdir(File.dirname(@config[:capass]), 0770)
        end

        begin
            File.open(@config[:capass], "w", 0600) { |f| f.print pass }
        rescue Errno::EACCES => detail
            raise Puppet::Error, detail.to_s
        end
        return pass
    end

    def getpass
        if @config[:capass] and File.readable?(@config[:capass])
            return File.read(@config[:capass])
        else
            raise Puppet::Error, "Could not read CA passfile %s" % @config[:capass]
        end
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
            :encrypt => @config[:capass],
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
        Puppet.config.params("ca").each { |param|
            param = param.intern if param.is_a? String
            if hash.include?(param)
                @config[param] = hash[param]
                Puppet[param] = hash[param]
                hash.delete(param)
            else
                @config[param] = Puppet[param]
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
                raise Puppet::DevError, "%s is undefined" % dir
            end
            unless FileTest.exists?(@config[dir])
                Puppet.recmkdir(@config[dir])
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
            system("ls -al %s" % Puppet[:capass])
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
