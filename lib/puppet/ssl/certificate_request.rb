require 'puppet/ssl'

# This constant just exists for us to use for adding our request terminii.
class Puppet::SSL::CertificateRequest # :nodoc:
    extend Puppet::Indirector

    indirects :certificate_request #, :terminus_class => :file

    attr_reader :name, :content

    # How to create a certificate request with our system defaults.
    def generate(key)
        Puppet.info "Creating a new SSL certificate request for %s" % name

        csr = OpenSSL::X509::Request.new
        csr.version = 0
        csr.subject = OpenSSL::X509::Name.new([["CN", name]])
        csr.public_key = key.public_key
        csr.sign(key, OpenSSL::Digest::MD5.new)

        @content = csr
    end

    def initialize(name)
        @name = name
    end
end
