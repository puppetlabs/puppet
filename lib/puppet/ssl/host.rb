require 'puppet/ssl'
require 'puppet/ssl/key'
require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_request'

# The class that manages all aspects of our SSL certificates --
# private keys, public keys, requests, etc.
class Puppet::SSL::Host
    # Yay, ruby's strange constant lookups.
    Key = Puppet::SSL::Key
    CertificateRequest = Puppet::SSL::CertificateRequest
    Certificate = Puppet::SSL::Certificate

    attr_reader :name

    attr_accessor :ca

    # Is this a ca host, meaning that all of its files go in the CA collections?
    def ca?
        ca
    end

    # Read our cert if necessary, fail if we can't find it (since it should
    # be created by someone else and returned through 'find').
    def certificate
        unless @certificate ||= Certificate.find(name)
            return nil
        end
        @certificate.content
    end

    # Read or create, then return, our certificate request.
    def certificate_request
        unless @certificate_request ||= CertificateRequest.find(name)
            return nil
        end
        @certificate_request.content
    end

    # Remove all traces of this ssl host
    def destroy
        [key, certificate, certificate_request].each do |instance|
            instance.class.destroy(instance) if instance
        end
    end

    # Request a signed certificate from a ca, if we can find one.
    def generate_certificate
        generate_certificate_request unless certificate_request

        @certificate = Certificate.new(name)
        if @certificate.generate(certificate_request)
            @certificate.save
            return true
        else
            return false
        end
    end

    # Generate and save a new certificate request.
    def generate_certificate_request
        generate_key unless key
        @certificate_request = CertificateRequest.new(name)
        @certificate_request.generate(key)
        @certificate_request.save
        return true
    end

    # Generate and save a new key.
    def generate_key
        @key = Key.new(name)
        @key.generate
        @key.save
        return true
    end

    # Read or create, then return, our key. The public key is part
    # of the private key.  We 
    def key
        unless @key ||= Key.find(name)
            return nil
        end
        @key.content
    end

    def initialize(name)
        @name = name
        @key = @certificate = @certificate_request = nil
        @ca = false
    end

    # Extract the public key from the private key.
    def public_key
        key.public_key
    end
end
