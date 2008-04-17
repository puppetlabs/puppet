require 'puppet/ssl'
require 'puppet/ssl/key'
require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_request'
require 'puppet/util/constant_inflector'

# The class that manages all aspects of our SSL certificates --
# private keys, public keys, requests, etc.
class Puppet::SSL::Host
    # Yay, ruby's strange constant lookups.
    Key = Puppet::SSL::Key
    CertificateRequest = Puppet::SSL::CertificateRequest
    Certificate = Puppet::SSL::Certificate

    extend Puppet::Util::ConstantInflector

    attr_reader :name
    attr_accessor :ca, :password_file

    CA_NAME = "ca"

    # This is the constant that people will use to mark that a given host is
    # a certificate authority.
    def self.ca_name
        CA_NAME
    end

    # Search for more than one host, optionally only specifying
    # an interest in hosts with a given file type.
    # This just allows our non-indirected class to have one of
    # indirection methods.
    def self.search(options = {})
        classes = [Key, CertificateRequest, Certificate]
        if klass = options[:for]
            classlist = [klass].flatten
        else
            classlist = [Key, CertificateRequest, Certificate]
        end

        # Collect the results from each class, flatten them, collect all of the names, make the name list unique,
        # then create a Host instance for each one.
        classlist.collect { |klass| klass.search }.flatten.collect { |r| r.name }.uniq.collect do |name|
            new(name)
        end
    end

    # Is this a ca host, meaning that all of its files go in the CA location?
    def ca?
        ca
    end

    def key
        return nil unless (defined?(@key) and @key) or @key = Key.find(name)
        @key.content
    end

    # This is the private key; we can create it from scratch
    # with no inputs.
    def generate_key
        @key = Key.new(name)

        # If a password file is set, then the key will be stored
        # encrypted by the password.
        @key.password_file = password_file if password_file
        @key.generate
        @key.save
        true
    end

    def certificate_request
        return nil unless (defined?(@certificate_request) and @certificate_request) or @certificate_request = CertificateRequest.find(name)
        @certificate_request.content
    end

    # Our certificate request requires the key but that's all.
    def generate_certificate_request
        generate_key unless key
        @certificate_request = CertificateRequest.new(name)
        @certificate_request.generate(key)
        @certificate_request.save
        return true
    end

    # There's no ability to generate a certificate -- if we don't have it, then we should be
    # automatically looking in the ca, and if the ca doesn't have it, we don't have one.
    def certificate
        return nil unless (defined?(@certificate) and @certificate) or @certificate = Certificate.find(name)
        @certificate.content
    end

    # Remove all traces of this ssl host
    def destroy
        [key, certificate, certificate_request].each do |instance|
            instance.class.destroy(instance) if instance
        end
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
