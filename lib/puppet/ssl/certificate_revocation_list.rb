require 'puppet/ssl/base'
require 'puppet/indirector'

# Manage the CRL.
class Puppet::SSL::CertificateRevocationList < Puppet::SSL::Base
    wraps OpenSSL::X509::CRL

    extend Puppet::Indirector
    indirects :certificate_revocation_list, :terminus_class => :file

    # Knows how to create a CRL with our system defaults.
    def generate(cert)
        Puppet.info "Creating a new certificate revocation list"
        @content = wrapped_class.new
        @content.issuer = cert.subject
        @content.version = 1

        @content
    end

    # The name doesn't actually matter; there's only one CRL.
    # We just need the name so our Indirector stuff all works more easily.
    def initialize(fakename)
        raise Puppet::Error, "Cannot manage the CRL when :cacrl is set to false" if [false, "false"].include?(Puppet[:cacrl])

        @name = "crl"
    end

    # Revoke the certificate with serial number SERIAL issued by this
    # CA, then write the CRL back to disk. The REASON must be one of the
    # OpenSSL::OCSP::REVOKED_* reasons
    def revoke(serial, cakey, reason = OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE)
        Puppet.notice "Revoked certificate with serial %s" % serial
        time = Time.now

        # Add our revocation to the CRL.
        revoked = OpenSSL::X509::Revoked.new
        revoked.serial = serial
        revoked.time = time
        enum = OpenSSL::ASN1::Enumerated(reason)
        ext = OpenSSL::X509::Extension.new("CRLReason", enum)
        revoked.add_extension(ext)
        @content.add_revoked(revoked)

        # Increment the crlNumber
        e = @content.extensions.find { |e| e.oid == 'crlNumber' }
        ext = @content.extensions.reject { |e| e.oid == 'crlNumber' }
        crlNum = OpenSSL::ASN1::Integer(e ? e.value.to_i + 1 : 0)
        ext << OpenSSL::X509::Extension.new("crlNumber", crlNum)
        @content.extensions = ext

        # Set last/next update
        @content.last_update = time
        # Keep CRL valid for 5 years
        @content.next_update = time + 5 * 365*24*60*60

        @content.sign(cakey, OpenSSL::Digest::SHA1.new)

        save
    end
end
