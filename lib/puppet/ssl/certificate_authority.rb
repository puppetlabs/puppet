require 'puppet/ssl/host'
require 'puppet/ssl/certificate_request'

# The class that knows how to sign certificates.  It creates
# a 'special' SSL::Host whose name is 'ca', thus indicating
# that, well, it's the CA.  There's some magic in the
# indirector/ssl_file terminus base class that does that
# for us.
#   This class mostly just signs certs for us, but
# it can also be seen as a general interface into all of the
# SSL stuff.
class Puppet::SSL::CertificateAuthority
    require 'puppet/ssl/certificate_factory'
    require 'puppet/ssl/inventory'
    require 'puppet/ssl/certificate_revocation_list'

    attr_reader :name, :host

    # Retrieve (or create, if necessary) the certificate revocation list.
    def crl
        unless defined?(@crl)
            # The crl is disabled.
            if ["false", false].include?(Puppet[:cacrl])
                @crl = nil
                return @crl
            end

            unless @crl = Puppet::SSL::CertificateRevocationList.find("whatever")
                @crl = Puppet::SSL::CertificateRevocationList.new("whatever")
                @crl.generate(host.certificate.content)
            end
        end
        @crl
    end

    # Delegate this to our Host class.
    def destroy(name)
        Puppet::SSL::Host.destroy(name)
    end

    # Generate a new certificate.
    def generate(name)
        raise ArgumentError, "A Certificate already exists for %s" % name if Puppet::SSL::Certificate.find(name)
        host = Puppet::SSL::Host.new(name)

        host.generate_certificate_request

        sign(name)
    end

    # Generate our CA certificate.
    def generate_ca_certificate
        generate_password unless password?

        host.generate_key unless host.key

        # Create a new cert request.  We do this
        # specially, because we don't want to actually
        # save the request anywhere.
        request = Puppet::SSL::CertificateRequest.new(host.name)
        request.generate(host.key)

        # Create a self-signed certificate.
        @certificate = sign(host.name, :ca, request)
    end

    def initialize
        Puppet.settings.use :main, :ssl, :ca

        @name = Puppet[:certname]

        @host = Puppet::SSL::Host.new(Puppet::SSL::Host.ca_name)
    end

    # Retrieve (or create, if necessary) our inventory manager.
    def inventory
        unless defined?(@inventory)
            @inventory = Puppet::SSL::Inventory.new
        end
        @inventory
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

    # Revoke a given certificate.
    def revoke(name)
        raise ArgumentError, "Cannot revoke certificates when the CRL is disabled" unless crl

        if cert = Puppet::SSL::Certificate.find(name)
            serial = cert.content.serial
        elsif ! serial = inventory.serial(name)
            raise ArgumentError, "Could not find a serial number for %s" % name
        end
        crl.revoke(serial, host.key.content)
    end

    # Sign a given certificate request.
    def sign(hostname, cert_type = :server, self_signing_csr = nil)
        # This is a self-signed certificate
        if self_signing_csr
            csr = self_signing_csr
            issuer = csr.content
        else
            generate_ca_certificate unless host.certificate

            unless csr = Puppet::SSL::CertificateRequest.find(hostname)
                raise ArgumentError, "Could not find certificate request for %s" % hostname
            end
            issuer = host.certificate.content
        end

        cert = Puppet::SSL::Certificate.new(hostname)
        cert.content = Puppet::SSL::CertificateFactory.new(cert_type, csr.content, issuer, next_serial).result
        cert.content.sign(host.key.content, OpenSSL::Digest::SHA1.new)

        Puppet.notice "Signed certificate request for %s" % hostname

        # Add the cert to the inventory before we save it, since
        # otherwise we could end up with it being duplicated, if
        # this is the first time we build the inventory file.
        inventory.add(cert)

        # Save the now-signed cert.  This should get routed correctly depending
        # on the certificate type.
        cert.save

        # And remove the CSR if this wasn't self signed.
        Puppet::SSL::CertificateRequest.destroy(csr.name) unless self_signing_csr

        return cert
    end

    # Verify a given host's certificate.
    def verify(name)
        unless cert = Puppet::SSL::Certificate.find(name)
            raise ArgumentError, "Could not find a certificate for %s" % name
        end
        store = OpenSSL::X509::Store.new
        store.add_file Puppet[:cacert]
        store.add_crl Puppet[:cacrl] if self.crl
        store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT

        unless store.verify(cert.content)
            raise "Certificate for %s failed verification" % name
        end
    end

    # List the waiting certificate requests.
    def waiting?
        Puppet::SSL::CertificateRequest.search("*").collect { |r| r.name }
    end
end
