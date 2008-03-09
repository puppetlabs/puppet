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

    # Read our cert if necessary, fail if we can't find it (since it should
    # be created by someone else and returned through 'find').
    def certificate
        unless @certificate ||= Certificate.find(name)
            Certificate.new(name).generate # throws an exception
        end
        @certificate
    end

    # Read or create, then return, our certificate request.
    def certificate_request
        unless @certificate_request ||= CertificateRequest.find(name)
            @certificate_request = CertificateRequest.new(name)
            @certificate_request.generate(key)
            @certificate_request.save
        end
        @certificate_request
    end

    # Remove all traces of this ssl host
    def destroy
        [key, certificate, certificate_request].each do |instance|
            instance.class.destroy(instance) if instance
        end
    end

    # Read or create, then return, our key. The public key is part
    # of the private key.
    def key
        unless @key ||= Key.find(name)
            @key = Key.new(name)
            @key.generate
            @key.save
        end
        @key
    end

    def initialize(name)
        @name = name
        @key = @certificate = @certificate_request = nil
    end

    # Extract the public key from the private key.
    def public_key
        key.public_key
    end
end
