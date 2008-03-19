require 'puppet/ssl/host'

# The class that knows how to sign certificates.  It's just a
# special case of the SSL::Host -- it's got a sign method,
# and it reads its info from a different location.
class Puppet::SSL::CertificateAuthority < Puppet::SSL::Host
    require 'puppet/ssl/certificate_factory'

    # Provide the path to our password, and read our special ca key.
    def read_key
        return nil unless FileTest.exist?(Puppet[:cakey])

        key = Puppet::SSL::Key.new(name)
        key.password_file = Puppet[:capass]
        key.read(Puppet[:cakey])

        return key
    end

    # Generate and write the key out.
    def generate_key
        @key = Key.new(name)
        @key.password_file = Puppet[:capass]
        @key.generate
        Puppet.settings.write(:cakey) do |f|
            f.print @key.to_s
        end
        true
    end

    # Read the special path to our key.
    def read_certificate
        return nil unless FileTest.exist?(Puppet[:cacert])
        cert = Puppet::SSL::Certificate.new(name)
        cert.read(Puppet[:cacert])

        return cert
    end

    # The CA creates a self-signed certificate, rather than relying
    # on someone else to do the work.
    def generate_certificate
        request = CertificateRequest.new(name)
        request.generate(key)

        # Create a self-signed certificate.
        @certificate = sign(request, :ca, true)

        Puppet.settings.write(:cacert) do |f|
            f.print @certificate.to_s
        end

        return true
    end

    def initialize
        # Always name the ca after the host we're running on.
        super(Puppet[:certname])

        setup_ca()
    end

    # Sign a given certificate request.
    def sign(host, cert_type = :server, self_signing_csr = nil)

        # This is a self-signed certificate
        if self_signing_csr
            csr = self_signing_csr
            issuer = csr.content
        else
            raise ArgumentError, "Cannot find CA certificate; cannot sign certificate for %s" % host unless certificate
            unless csr = Puppet::SSL::CertificateRequest.find(host, :in => :ca_file)
                raise ArgumentError, "Could not find certificate request for %s" % host
            end
            issuer = certificate.content
        end

        cert = Puppet::SSL::Certificate.new(host)
        cert.content = Puppet::SSL::CertificateFactory.new(cert_type, csr.content, issuer, next_serial).result

        # Save the now-signed cert, unless it's a self-signed cert, since we
        # assume it goes somewhere else.
        cert.save(:in => :ca_file) unless self_signing_csr

        return cert
    end

    # Do all of the initialization necessary to set up our
    # ca.
    def setup_ca
        generate_key unless key

        # Make sure we've got a password protecting our private key.
        generate_password unless password?

        # And then make sure we've got the whole kaboodle.  This will
        # create a self-signed CA certificate if we don't already have one,
        # and it will just read it in if we do.
        generate_certificate unless certificate
    end

    # Generate a new password for the CA.
    def generate_password
        pass = ""
        20.times { pass += (rand(74) + 48).chr }

        begin
            Puppet.settings.write(:capass) { |f| f.print pass }
        rescue Errno::EACCES => detail
            raise Puppet::Error, "Could not write CA password: %s" % detail.to_s
        end

        @password = pass

        return pass
    end

    # Read the next serial from the serial file, and increment the
    # file so this one is considered used.
    def next_serial
        serial = nil
        Puppet.settings.readwritelock(:serial) { |f|
            if FileTest.exist?(Puppet[:serial])
                serial = File.read(Puppet.settings[:serial]).chomp.hex
            else
                serial = 0x0
            end

            # We store the next valid serial, not the one we just used.
            f << "%04X" % (serial + 1)
        }

        return serial
    end

    # Does the password file exist?
    def password?
        FileTest.exist? Puppet[:capass]
    end
end
