require 'puppet/ssl'
require 'puppet/ssl/key'
require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_request'
require 'puppet/ssl/certificate_revocation_list'
require 'puppet/util/cacher'

# The class that manages all aspects of our SSL certificates --
# private keys, public keys, requests, etc.
class Puppet::SSL::Host
    # Yay, ruby's strange constant lookups.
    Key = Puppet::SSL::Key
    Certificate = Puppet::SSL::Certificate
    CertificateRequest = Puppet::SSL::CertificateRequest
    CertificateRevocationList = Puppet::SSL::CertificateRevocationList

    attr_reader :name
    attr_accessor :ca

    attr_writer :key, :certificate, :certificate_request

    class << self
        include Puppet::Util::Cacher

        cached_attr(:localhost) do
            result = new()
            result.generate unless result.certificate
            result.key # Make sure it's read in
            result
        end
    end

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
            # This is weird; we don't actually cache our keys, we
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
        else
            # Make sure we have no cache configured.  puppetmasterd
            # switches the configurations around a bit, so it's important
            # that we specify the configs for absolutely everything, every
            # time.
            Certificate.cache_class = nil
            CertificateRequest.cache_class = nil
            CertificateRevocationList.cache_class = nil
        end
    end

    CA_MODES = {
        # Our ca is local, so we use it as the ultimate source of information
        # And we cache files locally.
        :local => [:ca, :file],
        # We're a remote CA client.
        :remote => [:rest, :file],
        # We are the CA, so we don't have read/write access to the normal certificates.
        :only => [:ca],
        # We have no CA, so we just look in the local file store.
        :none => [:file]
    }

    # Specify how we expect to interact with our certificate authority.
    def self.ca_location=(mode)
        raise ArgumentError, "CA Mode can only be %s" % CA_MODES.collect { |m| m.to_s }.join(", ") unless CA_MODES.include?(mode)

        @ca_location = mode

        configure_indirection(*CA_MODES[@ca_location])
    end

    # Remove all traces of a given host
    def self.destroy(name)
        [Key, Certificate, CertificateRequest].collect { |part| part.destroy(name) }.any? { |x| x }
    end

    # Search for more than one host, optionally only specifying
    # an interest in hosts with a given file type.
    # This just allows our non-indirected class to have one of
    # indirection methods.
    def self.search(options = {})
        classlist = [options[:for] || [Key, CertificateRequest, Certificate]].flatten

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
        @key ||= Key.find(name)
    end

    # This is the private key; we can create it from scratch
    # with no inputs.
    def generate_key
        @key = Key.new(name)
        @key.generate
        begin
            @key.save
        rescue
            @key = nil
            raise
        end
        true
    end

    def certificate_request
        @certificate_request ||= CertificateRequest.find(name)
    end

    # Our certificate request requires the key but that's all.
    def generate_certificate_request
        generate_key unless key
        @certificate_request = CertificateRequest.new(name)
        @certificate_request.generate(key.content)
        begin
            @certificate_request.save
        rescue
            @certificate_request = nil
            raise
        end

        return true
    end

    def certificate
        unless @certificate
            generate_key unless key

            # get the CA cert first, since it's required for the normal cert
            # to be of any use.
            return nil unless Certificate.find("ca") unless ca?
            return nil unless @certificate = Certificate.find(name)

            unless certificate_matches_key?
                raise Puppet::Error, "Retrieved certificate does not match private key; please remove certificate from server and regenerate it with the current key"
            end
        end
        @certificate
    end

    def certificate_matches_key?
        return false unless key
        return false unless certificate

        return certificate.content.check_private_key(key.content)
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
        unless defined?(@ssl_store) and @ssl_store
            @ssl_store = OpenSSL::X509::Store.new
            @ssl_store.purpose = purpose

            # Use the file path here, because we don't want to cause
            # a lookup in the middle of setting our ssl connection.
            @ssl_store.add_file(Puppet[:localcacert])

            # If there's a CRL, add it to our store.
            if crl = Puppet::SSL::CertificateRevocationList.find("ca")
                @ssl_store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK if Puppet.settings[:certificate_revocation]
                @ssl_store.add_crl(crl.content)
            end
            return @ssl_store
        end
        @ssl_store
    end

    # Attempt to retrieve a cert, if we don't already have one.
    def wait_for_cert(time)
        begin
            return if certificate
            generate
            return if certificate
        rescue SystemExit,NoMemoryError
            raise
        rescue Exception => detail
            Puppet.err "Could not request certificate: %s" % detail.to_s
            if time < 1
                puts "Exiting; failed to retrieve certificate and waitforcert is disabled"
                exit(1)
            else
                sleep(time)
            end
            retry
        end

        if time < 1
            puts "Exiting; no certificate found and waitforcert is disabled"
            exit(1)
        end

        while true do
            sleep time
            begin
                break if certificate
                Puppet.notice "Did not receive certificate"
            rescue StandardError => detail
                Puppet.err "Could not request certificate: %s" % detail.to_s
            end
        end
    end
end

require 'puppet/ssl/certificate_authority'
