require 'puppet/ssl/base'
require 'puppet/indirector'

# Manage the CRL.
class Puppet::SSL::CertificateRevocationList < Puppet::SSL::Base
    wraps OpenSSL::X509::CRL

    extend Puppet::Indirector
    indirects :certificate_revocation_list, :terminus_class => :file

    # Convert a string into an instance.
    def self.from_s(string)
        instance = wrapped_class.new(string)
        result = new('foo') # The name doesn't matter
        result.content = instance
        result
    end

    # Because of how the format handler class is included, this
    # can't be in the base class.
    def self.supported_formats
        [:s]
    end

    # Knows how to create a CRL with our system defaults.
    def generate(cert, cakey)
        Puppet.info "Creating a new certificate revocation list"
        @content = wrapped_class.new
        @content.issuer = cert.subject
        @content.version = 1

        # Init the CRL number.
        crlNum = OpenSSL::ASN1::Integer(0)
        @content.extensions = [OpenSSL::X509::Extension.new("crlNumber", crlNum)]

        # Set last/next update
        @content.last_update = Time.now
        # Keep CRL valid for 5 years
        @content.next_update = Time.now + 5 * 365*24*60*60

        @content.sign(cakey, OpenSSL::Digest::SHA1.new)

        @content
    end

    # The name doesn't actually matter; there's only one CRL.
    # We just need the name so our Indirector stuff all works more easily.
    def initialize(fakename)
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
