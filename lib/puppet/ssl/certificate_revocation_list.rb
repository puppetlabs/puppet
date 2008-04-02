require 'puppet/ssl/base'

# Manage the CRL.
class Puppet::SSL::CertificateRevocationList < Puppet::SSL::Base
    wraps OpenSSL::X509::CRL

    # Knows how to create a CRL with our system defaults.
    def generate(cert, key)
        Puppet.info "Creating a new SSL key for %s" % name
        @content = wrapped_class.new
        @content.issuer = cert.subject
        @content.version = 1

        @content
    end

    def initialize(name, cert, key)
        raise Puppet::Error, "Cannot manage the CRL when :cacrl is set to false" if [false, "false"].include?(Puppet[:cacrl])

        @name = name

        read_or_generate(cert, key)
    end

    # A stupid indirection method to make this easier to test.  Yay.
    def read_or_generate(cert, key)
        unless read(Puppet[:cacrl])
            generate(cert, key)
            save(key)
        end
    end

    # Revoke the certificate with serial number SERIAL issued by this
    # CA. The REASON must be one of the OpenSSL::OCSP::REVOKED_* reasons
    def revoke(serial, reason = OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE)
        if @config[:cacrl] == 'false'
            raise Puppet::Error, "Revocation requires a CRL, but ca_crl is set to 'false'"
        end
        time = Time.now
        revoked = OpenSSL::X509::Revoked.new
        revoked.serial = serial
        revoked.time = time
        enum = OpenSSL::ASN1::Enumerated(reason)
        ext = OpenSSL::X509::Extension.new("CRLReason", enum)
        revoked.add_extension(ext)
        @content.add_revoked(revoked)
        store_crl
    end

    # Save the CRL to disk.  Note that none of the other Base subclasses
    # have this method, because they all use the indirector to find and save
    # the CRL.
    def save(key)
        # Increment the crlNumber
        e = @content.extensions.find { |e| e.oid == 'crlNumber' }
        ext = @content.extensions.reject { |e| e.oid == 'crlNumber' }
        crlNum = OpenSSL::ASN1::Integer(e ? e.value.to_i + 1 : 0)
        ext << OpenSSL::X509::Extension.new("crlNumber", crlNum)
        @content.extensions = ext

        # Set last/next update
        now = Time.now
        @content.last_update = now
        # Keep CRL valid for 5 years
        @content.next_update = now + 5 * 365*24*60*60

        sign_with_key(@content)
        Puppet.settings.write(:cacrl) do |f|
            f.puts @content.to_pem
        end
    end
end
