require 'sync'

class Puppet::SSLCertificates::CA
    include Puppet::Util::Warnings

    Certificate = Puppet::SSLCertificates::Certificate
    attr_accessor :keyfile, :file, :config, :dir, :cert, :crl

    def certfile
        @config[:cacert]
    end

    # Remove all traces of a given host.  This is kind of hackish, but, eh.
    def clean(host)
        host = host.downcase
        [:csrdir, :signeddir, :publickeydir, :privatekeydir, :certdir].each do |name|
            dir = Puppet[name]

            file = File.join(dir, host + ".pem")

            if FileTest.exists?(file)
                begin
                    if Puppet[:name] == "puppetca"
                        puts "Removing %s" % file
                    else
                        Puppet.info "Removing %s" % file
                    end
                    File.unlink(file)
                rescue => detail
                    raise Puppet::Error, "Could not delete %s: %s" %
                        [file, detail]
                end
            end

        end
    end

    def host2csrfile(hostname)
        File.join(Puppet[:csrdir], [hostname.downcase, "pem"].join("."))
    end

    # this stores signed certs in a directory unrelated to
    # normal client certs
    def host2certfile(hostname)
        File.join(Puppet[:signeddir], [hostname.downcase, "pem"].join("."))
    end

    # Turn our hostname into a Name object
    def thing2name(thing)
        thing.subject.to_a.find { |ary|
            ary[0] == "CN"
        }[1]
    end

    def initialize(hash = {})
        Puppet.settings.use(:main, :ca, :ssl)
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
        init_crl
        unless FileTest.exists?(@config[:serial])
            Puppet.settings.write(:serial) do |f|
                f << "%04X" % 1
            end
        end
    end

    # Generate a new password for the CA.
    def genpass
        pass = ""
        20.times { pass += (rand(74) + 48).chr }

        begin
            Puppet.settings.write(:capass) { |f| f.print pass }
        rescue Errno::EACCES => detail
            raise Puppet::Error, detail.to_s
        end
        return pass
    end

    # Get the CA password.
    def getpass
        if @config[:capass] and File.readable?(@config[:capass])
            return File.read(@config[:capass])
        else
            raise Puppet::Error, "Could not decrypt CA key with password: %s" % detail
        end
    end

    # Get the CA cert.
    def getcert
        if FileTest.exists?(@config[:cacert])
            @cert = OpenSSL::X509::Certificate.new(
                File.read(@config[:cacert])
            )
        else
            self.mkrootcert
        end
    end

    # Retrieve a client's CSR.
    def getclientcsr(host)
        csrfile = host2csrfile(host)
        unless File.exists?(csrfile)
            return nil
        end

        return OpenSSL::X509::Request.new(File.read(csrfile))
    end

    # Retrieve a client's certificate.
    def getclientcert(host)
        certfile = host2certfile(host)
        unless File.exists?(certfile)
            return [nil, nil]
        end

        return [OpenSSL::X509::Certificate.new(File.read(certfile)), @cert]
    end

    # List certificates waiting to be signed.  This returns a list of hostnames, not actual
    # files -- the names can be converted to full paths with host2csrfile.
    def list(dummy_argument=:work_arround_for_ruby_GC_bug)
        return Dir.entries(Puppet[:csrdir]).find_all { |file|
            file =~ /\.pem$/
        }.collect { |file|
            file.sub(/\.pem$/, '')
        }
    end

    # List signed certificates.  This returns a list of hostnames, not actual
    # files -- the names can be converted to full paths with host2csrfile.
    def list_signed(dummy_argument=:work_arround_for_ruby_GC_bug)
        return Dir.entries(Puppet[:signeddir]).find_all { |file|
            file =~ /\.pem$/
        }.collect { |file|
            file.sub(/\.pem$/, '')
        }
    end

    # Create the root certificate.
    def mkrootcert
        # Make the root cert's name the FQDN of the host running the CA.
        name = Facter["hostname"].value
        if domain = Facter["domain"].value
            name += "." + domain
        end
        cert = Certificate.new(
            :name => name,
            :cert => @config[:cacert],
            :encrypt => @config[:capass],
            :key => @config[:cakey],
            :selfsign => true,
            :ttl => ttl,
            :type => :ca
        )

        # This creates the cakey file
        Puppet::Util::SUIDManager.asuser(Puppet[:user], Puppet[:group]) do
            @cert = cert.mkselfsigned
        end
        Puppet.settings.write(:cacert) do |f|
            f.puts @cert.to_pem
        end
        Puppet.settings.write(:capub) do |f|
            f.puts @cert.public_key
        end
        return cert
    end

    def removeclientcsr(host)
        csrfile = host2csrfile(host)
        unless File.exists?(csrfile)
            raise Puppet::Error, "No certificate request for %s" % host
        end

        File.unlink(csrfile)
    end

    # Revoke the certificate with serial number SERIAL issued by this
    # CA. The REASON must be one of the OpenSSL::OCSP::REVOKED_* reasons
    def revoke(serial, reason = OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE)
        time = Time.now
        revoked = OpenSSL::X509::Revoked.new
        revoked.serial = serial
        revoked.time = time
        enum = OpenSSL::ASN1::Enumerated(reason)
        ext = OpenSSL::X509::Extension.new("CRLReason", enum)
        revoked.add_extension(ext)
        @crl.add_revoked(revoked)
        store_crl
    end

    # Take the Puppet config and store it locally.
    def setconfig(hash)
        @config = {}
        Puppet.settings.params("ca").each { |param|
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
        }
    end

    # Sign a given certificate request.
    def sign(csr)
        unless csr.is_a?(OpenSSL::X509::Request)
            raise Puppet::Error,
                "CA#sign only accepts OpenSSL::X509::Request objects, not %s" %
                csr.class
        end

        unless csr.verify(csr.public_key)
            raise Puppet::Error, "CSR sign verification failed"
        end

        serial = nil
        Puppet.settings.readwritelock(:serial) { |f|
            serial = File.read(@config[:serial]).chomp.hex
            # increment the serial
            f << "%04X" % (serial + 1)
        }

        newcert = Puppet::SSLCertificates.mkcert(
            :type => :server,
            :name => csr.subject,
            :ttl => ttl,
            :issuer => @cert,
            :serial => serial,
            :publickey => csr.public_key
        )


        sign_with_key(newcert)

        self.storeclientcert(newcert)

        return [newcert, @cert]
    end

    # Store the client's CSR for later signing.  This is called from
    # server/ca.rb, and the CSRs are deleted once the certificate is actually
    # signed.
    def storeclientcsr(csr)
        host = thing2name(csr)

        csrfile = host2csrfile(host)
        if File.exists?(csrfile)
            raise Puppet::Error, "Certificate request for %s already exists" % host
        end

        Puppet.settings.writesub(:csrdir, csrfile) do |f|
            f.print csr.to_pem
        end
    end

    # Store the certificate that we generate.
    def storeclientcert(cert)
        host = thing2name(cert)

        certfile = host2certfile(host)
        if File.exists?(certfile)
            Puppet.notice "Overwriting signed certificate %s for %s" %
                [certfile, host]
        end

        Puppet::SSLCertificates::Inventory::add(cert)
        Puppet.settings.writesub(:signeddir, certfile) do |f|
            f.print cert.to_pem
        end
    end

    # TTL for new certificates in seconds. If config param :ca_ttl is set,
    # use that, otherwise use :ca_days for backwards compatibility
    def ttl
        days = @config[:ca_days]
        if days && days.size > 0
            warnonce "Parameter ca_ttl is not set. Using depecated ca_days instead."
            return @config[:ca_days] * 24 * 60 * 60
        else
            ttl = @config[:ca_ttl]
            if ttl.is_a?(String)
                unless ttl =~ /^(\d+)(y|d|h|s)$/
                    raise ArgumentError, "Invalid ca_ttl #{ttl}"
                end
                case $2
                when 'y'
                    unit = 365 * 24 * 60 * 60
                when 'd'
                    unit = 24 * 60 * 60
                when 'h'
                    unit = 60 * 60
                when 's'
                    unit = 1
                else
                    raise ArgumentError, "Invalid unit for ca_ttl #{ttl}"
                end
                return $1.to_i * unit
            else
                return ttl
            end
        end
    end

    private
    def init_crl
        if FileTest.exists?(@config[:cacrl])
            @crl = OpenSSL::X509::CRL.new(
                File.read(@config[:cacrl])
            )
        else
            # Create new CRL
            @crl = OpenSSL::X509::CRL.new
            @crl.issuer = @cert.subject
            @crl.version = 1
            store_crl
            @crl
        end
    end

    def store_crl
        # Increment the crlNumber
        e = @crl.extensions.find { |e| e.oid == 'crlNumber' }
        ext = @crl.extensions.reject { |e| e.oid == 'crlNumber' }
        crlNum = OpenSSL::ASN1::Integer(e ? e.value.to_i + 1 : 0)
        ext << OpenSSL::X509::Extension.new("crlNumber", crlNum)
        @crl.extensions = ext

        # Set last/next update
        now = Time.now
        @crl.last_update = now
        # Keep CRL valid for 5 years
        @crl.next_update = now + 5 * 365*24*60*60

        sign_with_key(@crl)
        Puppet.settings.write(:cacrl) do |f|
            f.puts @crl.to_pem
        end
    end

    def sign_with_key(signable, digest = OpenSSL::Digest::SHA1.new)
        cakey = nil
        if @config[:password]
            begin
                cakey = OpenSSL::PKey::RSA.new(
                    File.read(@config[:cakey]), @config[:password]
                )
            rescue
                raise Puppet::Error,
                    "Decrypt of CA private key with password stored in @config[:capass] not possible"
            end
        else
            cakey = OpenSSL::PKey::RSA.new(
                File.read(@config[:cakey])
            )
        end

        unless @cert.check_private_key(cakey)
            raise Puppet::Error, "CA Certificate is invalid"
        end

        signable.sign(cakey, digest)
    end
end

