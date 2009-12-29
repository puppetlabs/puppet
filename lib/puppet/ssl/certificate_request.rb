require 'puppet/ssl/base'

# Manage certificate requests.
class Puppet::SSL::CertificateRequest < Puppet::SSL::Base
    wraps OpenSSL::X509::Request

    extend Puppet::Indirector
    indirects :certificate_request, :terminus_class => :file

    # Convert a string into an instance.
    def self.from_s(string)
        instance = wrapped_class.new(string)
        name = instance.subject.to_s.sub(/\/CN=/i, '').downcase
        result = new(name)
        result.content = instance
        result
    end

    # Because of how the format handler class is included, this
    # can't be in the base class.
    def self.supported_formats
        [:s]
    end

    # How to create a certificate request with our system defaults.
    def generate(key)
        Puppet.info "Creating a new SSL certificate request for %s" % name

        # Support either an actual SSL key, or a Puppet key.
        key = key.content if key.is_a?(Puppet::SSL::Key)

        # If we're a CSR for the CA, then use the real certname, rather than the
        # fake 'ca' name.  This is mostly for backward compatibility with 0.24.x,
        # but it's also just a good idea.
        common_name = name == Puppet::SSL::CA_NAME ? Puppet.settings[:ca_name] : name

        csr = OpenSSL::X509::Request.new
        csr.version = 0
        csr.subject = OpenSSL::X509::Name.new([["CN", common_name]])
        csr.public_key = key.public_key
        csr.sign(key, OpenSSL::Digest::MD5.new)

        raise Puppet::Error, "CSR sign verification failed; you need to clean the certificate request for %s on the server" % name unless csr.verify(key.public_key)

        @content = csr
        Puppet.info "Certificate Request fingerprint (md5): #{fingerprint}"
        @content
    end

    def save(args = {})
        super()

        # Try to autosign the CSR.
        if ca = Puppet::SSL::CertificateAuthority.instance
            ca.autosign
        end
    end
end
