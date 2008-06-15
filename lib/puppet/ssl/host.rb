require 'puppet/ssl'
require 'puppet/ssl/key'
require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_request'
require 'puppet/ssl/certificate_revocation_list'
require 'puppet/util/constant_inflector'

# The class that manages all aspects of our SSL certificates --
# private keys, public keys, requests, etc.
class Puppet::SSL::Host
    # Yay, ruby's strange constant lookups.
    Key = Puppet::SSL::Key
    Certificate = Puppet::SSL::Certificate
    CertificateRequest = Puppet::SSL::CertificateRequest
    CertificateRevocationList = Puppet::SSL::CertificateRevocationList

    extend Puppet::Util::ConstantInflector

    attr_reader :name
    attr_accessor :ca

    attr_writer :key, :certificate, :certificate_request

    CA_NAME = "ca"

    # This is the constant that people will use to mark that a given host is
    # a certificate authority.
    def self.ca_name
        CA_NAME
    end

    class << self
        attr_reader :ca_location
    end

    # Configure how our various classes interact with their various terminuses.
    def self.configure_indirection(terminus, cache = nil)
        Certificate.terminus_class = terminus
        CertificateRequest.terminus_class = terminus
        CertificateRevocationList.terminus_class = terminus

        if cache
            # This is weird; we don't actually cache our keys or CRL, we
            # use what would otherwise be the cache as our normal
            # terminus.
            Key.terminus_class = cache
        else
            Key.terminus_class = terminus
        end

        if cache
            Certificate.cache_class = cache
            CertificateRequest.cache_class = cache
            CertificateRevocationList.cache_class = cache
        end
    end

    # Specify how we expect to interact with our certificate authority.
    def self.ca_location=(mode)
        raise ArgumentError, "CA Mode can only be :local, :remote, or :none" unless [:local, :remote, :none].include?(mode)

        @ca_mode = mode

        case @ca_mode
        when :local:
            # Our ca is local, so we use it as the ultimate source of information
            # And we cache files locally.
            configure_indirection :ca, :file
        when :remote:
            configure_indirection :rest, :file
        when :none:
            # We have no CA, so we just look in the local file store.
            configure_indirection :file
        end
    end

    # Remove all traces of a given host
    def self.destroy(name)
        [Key, Certificate, CertificateRequest].inject(false) do |result, klass|
            if klass.destroy(name)
                result = true
            end
            result
        end
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
        return nil unless @key ||= Key.find(name)
        @key
    end

    # This is the private key; we can create it from scratch
    # with no inputs.
    def generate_key
        @key = Key.new(name)
        @key.generate
        @key.save
        true
    end

    def certificate_request
        return nil unless @certificate_request ||= CertificateRequest.find(name)
        @certificate_request
    end

    # Our certificate request requires the key but that's all.
    def generate_certificate_request
        generate_key unless key
        @certificate_request = CertificateRequest.new(name)
        @certificate_request.generate(key.content)
        @certificate_request.save
        return true
    end

    def certificate
        return nil unless @certificate ||= Certificate.find(name)
        @certificate
    end

    # Generate all necessary parts of our ssl host.
    def generate
        generate_key unless key
        generate_certificate_request unless certificate_request

        # If we can get a CA instance, then we're a valid CA, and we
        # should use it to sign our request; else, just try to read
        # the cert.
        if ! certificate() and ca = Puppet::SSL::CertificateAuthority.instance
            ca.sign(self.name)
        end
    end

    def initialize(name = nil)
        @name = (name || Puppet[:certname]).downcase
        @key = @certificate = @certificate_request = nil
        @ca = (name == self.class.ca_name)
    end

    # Extract the public key from the private key.
    def public_key
        key.content.public_key
    end

    # Create/return a store that uses our SSL info to validate
    # connections.
    def ssl_store(purpose = OpenSSL::X509::PURPOSE_ANY)
        store = OpenSSL::X509::Store.new
        store.purpose = purpose

        store.add_file(Puppet[:localcacert])

        # If there's a CRL, add it to our store.
        if crl = Puppet::SSL::CertificateRevocationList.find("ca")
            store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK
            store.add_crl(crl.content)
        end
        return store
    end
end

require 'puppet/ssl/certificate_authority'
