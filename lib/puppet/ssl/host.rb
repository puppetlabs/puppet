require 'puppet/indirector'
require 'puppet/ssl'
require 'puppet/ssl/key'
require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_request'
require 'puppet/ssl/certificate_revocation_list'
require 'puppet/ssl/certificate_request_attributes'
require 'puppet/rest_client/routes'
require 'puppet/rest_client/client'
require 'puppet/rest_client/response_handler'

# The class that manages all aspects of our SSL certificates --
# private keys, public keys, requests, etc.
class Puppet::SSL::Host
  # Yay, ruby's strange constant lookups.
  Key = Puppet::SSL::Key
  CA_NAME = Puppet::SSL::CA_NAME
  Certificate = Puppet::SSL::Certificate
  CertificateRequest = Puppet::SSL::CertificateRequest
  CertificateRevocationList = Puppet::SSL::CertificateRevocationList

  extend Puppet::Indirector
  indirects :certificate_status, :terminus_class => :file, :doc => <<DOC
    This indirection represents the host that ties a key, certificate, and certificate request together.
    The indirection key is the certificate CN (generally a hostname).
DOC

  attr_reader :name
  attr_accessor :ca

  attr_writer :key, :certificate, :certificate_request

  # This accessor is used in instances for indirector requests to hold desired state
  attr_accessor :desired_state

  def self.localhost
    return @localhost if @localhost
    @localhost = new
    @localhost.generate unless @localhost.certificate
    @localhost.key
    @localhost
  end

  def self.reset
    @localhost = nil
  end

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
    Certificate.indirection.terminus_class = terminus
    CertificateRequest.indirection.terminus_class = terminus
    CertificateRevocationList.indirection.terminus_class = terminus

    host_map = {:ca => :file, :disabled_ca => nil, :file => nil, :rest => :rest}
    if term = host_map[terminus]
      self.indirection.terminus_class = term
    else
      self.indirection.reset_terminus_class
    end

    if cache
      # This is weird; we don't actually cache our keys, we
      # use what would otherwise be the cache as our normal
      # terminus.
      Key.indirection.terminus_class = cache
    else
      Key.indirection.terminus_class = terminus
    end

    if cache
      Certificate.indirection.cache_class = cache
      CertificateRequest.indirection.cache_class = cache
      CertificateRevocationList.indirection.cache_class = cache
    else
      # Make sure we have no cache configured.  puppet master
      # switches the configurations around a bit, so it's important
      # that we specify the configs for absolutely everything, every
      # time.
      Certificate.indirection.cache_class = nil
      CertificateRequest.indirection.cache_class = nil
      CertificateRevocationList.indirection.cache_class = nil
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
    :none => [:disabled_ca]
  }

  # Specify how we expect to interact with our certificate authority.
  def self.ca_location=(mode)
    modes = CA_MODES.collect { |m, vals| m.to_s }.join(", ")
    raise ArgumentError, _("CA Mode can only be one of: %{modes}") % { modes: modes } unless CA_MODES.include?(mode)

    @ca_location = mode

    configure_indirection(*CA_MODES[@ca_location])
  end

  # Puppet::SSL::Host is actually indirected now so the original implementation
  # has been moved into the certificate_status indirector.  This method is in-use
  # in `puppet cert -c <certname>`.
  def self.destroy(name)
    indirection.destroy(name)
  end

  def self.from_data_hash(data)
    instance = new(data["name"])
    if data["desired_state"]
      instance.desired_state = data["desired_state"]
    end
    instance
  end

  # Puppet::SSL::Host is actually indirected now so the original implementation
  # has been moved into the certificate_status indirector.  This method does not
  # appear to be in use in `puppet cert -l`.
  def self.search(options = {})
    indirection.search("*", options)
  end

  # Is this a ca host, meaning that all of its files go in the CA location?
  def ca?
    ca
  end

  def key
    @key ||= Key.indirection.find(name)
  end

  # This is the private key; we can create it from scratch
  # with no inputs.
  def generate_key
    @key = Key.new(name)
    @key.generate
    begin
      Key.indirection.save(@key)
    rescue
      @key = nil
      raise
    end
    true
  end

  def certificate_request
    @certificate_request ||= CertificateRequest.indirection.find(name)
  end

  # Our certificate request requires the key but that's all.
  def generate_certificate_request(options = {})
    generate_key unless key

    # If this CSR is for the current machine...
    if name == Puppet[:certname].downcase
      # ...add our configured dns_alt_names
      if Puppet[:dns_alt_names] and Puppet[:dns_alt_names] != ''
        options[:dns_alt_names] ||= Puppet[:dns_alt_names]
      elsif Puppet::SSL::CertificateAuthority.ca? and fqdn = Facter.value(:fqdn) and domain = Facter.value(:domain)
        options[:dns_alt_names] = "puppet, #{fqdn}, puppet.#{domain}"
      end
    end

    csr_attributes = Puppet::SSL::CertificateRequestAttributes.new(Puppet[:csr_attributes])
    if csr_attributes.load
      options[:csr_attributes] = csr_attributes.custom_attributes
      options[:extension_requests] = csr_attributes.extension_requests
    end

    @certificate_request = CertificateRequest.new(name)
    @certificate_request.generate(key.content, options)
    begin
      CertificateRequest.indirection.save(@certificate_request)
    rescue
      @certificate_request = nil
      raise
    end

    true
  end

  # Loads the certificate for this host. If configured to use an
  # in-memory indirector terminus, it attempts to retrieve the cert with
  # `indirection.find`. For all other cases, it first attempts to load
  # the cert from disk, then to download it from the CA if this fails.
  #
  # The indirector memory terminus is only used for testing the Ruby CA,
  # so when that gets removed, this logic can go with it.
  #
  # @param [String] cert_name the name of the cert to load
  # @return Puppet::SSL::Certificate if found, nil otherwise
  def get_certificate(cert_name)
    # The memory terminus is used for testing
    if Puppet::SSL::Certificate.indirection.terminus_class == :memory
      return Puppet::SSL::Certificate.indirection.find(cert_name)
    end

    file_path = certificate_location(cert_name)
    if Puppet::FileSystem.exist?(file_path)
      # Check if we already have the cert on disk
      if cert_name == 'ca'
        return load_certs(Puppet::FileSystem.read(file_path))[0]
      else
        return OpenSSL::X509::Certificate.new(Puppet::FileSystem.read(file_path))
      end
    elsif Puppet::SSL::Host.ca_location == :remote
      # Certificate not found on disk, and we have a remote ca,
      # so attempt to download it and save it to file_path
      if cert_name == 'ca'
        # The CA cert may be a chain, if our CA is an intermediate CA
        cert_bundle = download_ca_certificate_bundle
        if cert_bundle
          save_certificate_bundle(cert_bundle, file_path)
          return cert_bundle[0]
        end
      else
        cert = download_certificate(cert_name)
        if cert
          save_certificate(cert, file_path)
          return cert
        end
      end
    end
  end

  # Logic for detecting the cert's location on disk, based on `ca_location`
  # and whether or not we are looking for the CA cert.
  #
  # @param [String] cert_name the name of the cert to find
  # @return [String] filesystem location of the requested cert. Used both
  # for loading and for saving.
  def certificate_location(cert_name)
    if Puppet::SSL::Host.ca_location == :only
      if cert_name == 'ca'
        file_path = Puppet.settings[:cacert]
      else
        file_path = File.join(Puppet.settings[:signeddir], "#{name}.pem")
      end
    else
      if cert_name == 'ca'
        file_path = Puppet.settings[:localcacert]
      else
        file_path = File.join(Puppet.settings[:certdir], "#{name}.pem")
      end
    end
    return file_path
  end
  private :certificate_location

  def download_ca_certificate_bundle
    response = Puppet::Rest::Routes.get_certificate(
      Puppet::Rest::Client.new(OpenSSL::SSL::VERIFY_NONE),
      'ca')
    if response.ok?
      _, body = Puppet::Rest::ResponseHandler.parse_response(response)
      certs = load_certs(body)
    else
      Puppet.error _('Could not download CA certificate, aborting.')
    end
  end
  private :download_ca_certificate_bundle

  # return [OpenSSL::X509::Certificate] the downloaded client cert,
  #        or nil if none were found
  def download_client_cert
    response = Puppet::Rest::Routes.get_certificate(
      Puppet::Rest::Client.new(OpenSSL::SSL::VERIFY_NONE),
      name)
    if response.ok?
      _, body = Puppet::Rest::ResponseHandler.parse_response(response)
      cert = OpenSSL::X509::Certificate.new(body)
    else
      nil
    end
  end
  private :download_client_cert

  # Parse OpenSSL certificates from the given string
  # @param [String] cert_bundle a string containing one or more certificates
  #        in PEM format
  # @return an array of OpenSSL::X509::Certificates
  def load_certs(cert_bundle)
    delimiters = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m
    cert_bundle.scan(delimiters).map do |cert|
      OpenSSL::X509::Certificate.new(cert)
    end
  end
  private :load_certs

  def save_certificate_bundle(cert_bundle, file_path)
    bundle_string = ''
    cert_bundle.each do |cert|
      bundle_string += cert.to_s
    end
    Puppet::Util.replace_file(file_path, 'w:UTF-8') do |f|
      f.write(bundle_string)
    end
  end

  # Saves the body of `response` to disk at `file_path`,
  # if the response contains one or more valid certs.
  #
  # @param [Puppet::SSL::Certificate] cert the certficate object to save
  # @param [String] file_path location to save the cert
  # @return Puppet::SSL::Certificate if successful, nil otherwise
  def save_certificate(cert, file_path)
    Puppet::Util.replace_file(file_path, 'w:UTF-8') do |f|
      f.write(cert.to_s)
    end
  end
  private :save_certificate

  def certificate
    unless @certificate
      generate_key unless key

      # get the CA cert first, since it's required for the normal cert
      # to be of any use. If the CA cert cannot be found, return
      if !ca? && !get_certificate('ca')
        return nil
      end

      @certificate = get_certificate(name)
      # if no existing certificate, don't proceed to validate
      return nil unless @certificate

      validate_certificate_with_key
    end
    @certificate
  end

  def validate_certificate_with_key
    raise Puppet::Error, _("No certificate to validate.") unless certificate
    raise Puppet::Error, _("No private key with which to validate certificate with fingerprint: %{fingerprint}") % { fingerprint: certificate.fingerprint } unless key
    unless certificate.check_private_key(key.content)
      raise Puppet::Error, _(<<ERROR_STRING) % { fingerprint: certificate.fingerprint, cert_name: Puppet[:certname], ssl_dir: Puppet[:ssldir], cert_dir: Puppet[:certdir].gsub('/', '\\') }
The certificate retrieved from the master does not match the agent's private key. Did you forget to run as root?
Certificate fingerprint: %{fingerprint}
To fix this, remove the certificate from both the master and the agent and then start a puppet run, which will automatically regenerate a certificate.
On the master:
  puppet cert clean %{cert_name}
On the agent:
  1a. On most platforms: find %{ssl_dir} -name %{cert_name}.pem -delete
  1b. On Windows: del "%{cert_dir}\\%{cert_name}.pem" /f
  2. puppet agent -t
ERROR_STRING
    end
  end

  # Generate all necessary parts of our ssl host.
  def generate
    generate_key unless key
    # ask indirector to find any existing requests and download them
    existing_request = certificate_request

    # if CSR downloaded from master, but the local keypair was just generated and
    # does not match the public key in the CSR, fail hard
    if !existing_request.nil? &&
      (key.content.public_key.to_s != existing_request.content.public_key.to_s)

      raise Puppet::Error, _(<<ERROR_STRING) % { fingerprint: existing_request.fingerprint, csr_public_key: existing_request.content.public_key.to_text, agent_public_key: key.content.public_key.to_text, cert_name: Puppet[:certname], ssl_dir: Puppet[:ssldir], cert_dir: Puppet[:certdir].gsub('/', '\\') }
The CSR retrieved from the master does not match the agent's public key.
CSR fingerprint: %{fingerprint}
CSR public key: %{csr_public_key}
Agent public key: %{agent_public_key}
To fix this, remove the CSR from both the master and the agent and then start a puppet run, which will automatically regenerate a CSR.
On the master:
  puppet cert clean %{cert_name}
On the agent:
  1a. On most platforms: find %{ssl_dir} -name %{cert_name}.pem -delete
  1b. On Windows: del "%{cert_dir}\\%{cert_name}.pem" /f
  2. puppet agent -t
ERROR_STRING
    end
    generate_certificate_request unless existing_request

    # If we can get a CA instance, then we're a valid CA, and we
    # should use it to sign our request; else, just try to read
    # the cert.
    if ! certificate and ca = Puppet::SSL::CertificateAuthority.instance
      ca.sign(self.name, {allow_dns_alt_names: true})
    end
  end

  def initialize(name = nil)
    @name = (name || Puppet[:certname]).downcase
    Puppet::SSL::Base.validate_certname(@name)
    @key = @certificate = @certificate_request = nil
    @ca = (name == self.class.ca_name)
  end

  # Extract the public key from the private key.
  def public_key
    key.content.public_key
  end

  # Extract the subject alternative names from this host's certificate
  def subject_alt_names
    alts = certificate.extensions.find{|ext| ext.oid == "subjectAltName"}
    return [] unless alts
    alts.value.split(/\s*,\s*/)
  end

  # Create/return a store that uses our SSL info to validate
  # connections.
  def ssl_store(purpose = OpenSSL::X509::PURPOSE_ANY)
    if @ssl_store.nil?
      @ssl_store = build_ssl_store(purpose)
    end
    @ssl_store
  end

  def to_data_hash
    my_cert = @certificate || Puppet::SSL::Certificate.indirection.find(name)
    result = { 'name'  => name }

    my_state = state

    result['state'] = my_state
    result['desired_state'] = desired_state if desired_state

    thing_to_use = (my_state == 'requested') ? certificate_request : my_cert

    # this is for backwards-compatibility
    # we should deprecate it and transition people to using
    # json[:fingerprints][:default]
    # It appears that we have no internal consumers of this api
    # --jeffweiss 30 aug 2012
    result['fingerprint'] = thing_to_use.fingerprint

    # The above fingerprint doesn't tell us what message digest algorithm was used
    # No problem, except that the default is changing between 2.7 and 3.0. Also, as
    # we move to FIPS 140-2 compliance, MD5 is no longer allowed (and, gasp, will
    # segfault in rubies older than 1.9.3)
    # So, when we add the newer fingerprints, we're explicit about the hashing
    # algorithm used.
    # --jeffweiss 31 july 2012
    result['fingerprints'] = {}
    result['fingerprints']['default'] = thing_to_use.fingerprint

    suitable_message_digest_algorithms.each do |md|
      result['fingerprints'][md.to_s] = thing_to_use.fingerprint md
    end
    result['dns_alt_names'] = thing_to_use.subject_alt_names

    result
  end

  # eventually we'll probably want to move this somewhere else or make it
  # configurable
  # --jeffweiss 29 aug 2012
  def suitable_message_digest_algorithms
    [:SHA1, :SHA224, :SHA256, :SHA384, :SHA512]
  end

  # Attempt to retrieve a cert, if we don't already have one.
  def wait_for_cert(time)
    begin
      return if certificate
      generate
      return if certificate
    rescue StandardError => detail
      Puppet.log_exception(detail, _("Could not request certificate: %{message}") % { message: detail.message })
      if time < 1
        puts _("Exiting; failed to retrieve certificate and waitforcert is disabled")
        exit(1)
      else
        sleep(time)
      end
      retry
    end

    if time < 1
      puts _("Exiting; no certificate found and waitforcert is disabled")
      exit(1)
    end

    while true
      sleep time
      begin
        break if certificate
        Puppet.notice _("Did not receive certificate")
      rescue StandardError => detail
        Puppet.log_exception(detail, _("Could not request certificate: %{message}") % { message: detail.message })
      end
    end
  end

  def state
    if certificate_request
      return 'requested'
    end

    begin
      Puppet::SSL::CertificateAuthority.new.verify(name)
      return 'signed'
    rescue Puppet::SSL::CertificateAuthority::CertificateVerificationError
      return 'revoked'
    end
  end

  private

  def build_ssl_store(purpose)
    store = OpenSSL::X509::Store.new
    store.purpose = purpose

    # Use the file path here, because we don't want to cause
    # a lookup in the middle of setting our ssl connection.
    store.add_file(Puppet[:localcacert])

    # If we're doing revocation and there's a CRL, add it to our store.
    if Puppet.lookup(:certificate_revocation)
      if crl = Puppet::SSL::CertificateRevocationList.indirection.find(CA_NAME)
        flags = OpenSSL::X509::V_FLAG_CRL_CHECK
        if Puppet.lookup(:certificate_revocation) == :chain
          flags |= OpenSSL::X509::V_FLAG_CRL_CHECK_ALL
        end

        store.flags = flags
        store.add_crl(crl.content)
      else
        Puppet.debug _("Certificate revocation checking is enabled but a CRL cannot be found; CRL checking will not be performed.")
      end
    end
    store
  end
end

require 'puppet/ssl/certificate_authority'
