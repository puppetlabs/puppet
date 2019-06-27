require 'puppet/ssl'
require 'puppet/ssl/key'
require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_request'
require 'puppet/ssl/certificate_request_attributes'
require 'puppet/ssl/state_machine'
require 'puppet/rest/errors'
require 'puppet/rest/routes'

# The class that manages all aspects of our SSL certificates --
# private keys, public keys, requests, etc.
class Puppet::SSL::Host
  # Yay, ruby's strange constant lookups.
  Key = Puppet::SSL::Key
  CA_NAME = Puppet::SSL::CA_NAME
  Certificate = Puppet::SSL::Certificate
  CertificateRequest = Puppet::SSL::CertificateRequest

  attr_reader :name, :device, :crl_path

  attr_writer :key, :certificate, :certificate_request, :crl_usage

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

  # Configure how our various classes interact with their various terminuses.
  def self.configure_indirection(terminus, cache = nil)
    Certificate.indirection.terminus_class = terminus
    CertificateRequest.indirection.terminus_class = terminus

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
    else
      # Make sure we have no cache configured.  puppet master
      # switches the configurations around a bit, so it's important
      # that we specify the configs for absolutely everything, every
      # time.
      Certificate.indirection.cache_class = nil
      CertificateRequest.indirection.cache_class = nil
    end
  end

  def self.from_data_hash(data)
    instance = new(data["name"])
    if data["desired_state"]
      instance.desired_state = data["desired_state"]
    end
    instance
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

  # Our certificate request requires the key but that's all.
  def generate_certificate_request(options = {})
    generate_key unless key

    # If this CSR is for the current machine...
    if name == Puppet[:certname].downcase
      # ...add our configured dns_alt_names
      if Puppet[:dns_alt_names] and Puppet[:dns_alt_names] != ''
        options[:dns_alt_names] ||= Puppet[:dns_alt_names]
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
      submit_certificate_request(@certificate_request)
      save_certificate_request(@certificate_request)
    rescue
      @certificate_request = nil
      raise
    end

    true
  end

  def certificate
    unless @certificate
      generate_key unless key

      # get CA and optional CRL
      sm = Puppet::SSL::StateMachine.new(onetime: true)
      sm.ensure_ca_certificates

      cert = get_host_certificate
      return nil unless cert

      validate_certificate_with_key(cert)
      @certificate = cert
    end
    @certificate
  end

  # The puppet parameters for commands output by the validate_ methods depend
  # upon whether this is an agent or a device.

  def clean_params
    @device ? "--target #{Puppet[:certname]}" : ''
  end

  def puppet_params
    @device ? "device -v --target #{Puppet[:certname]}" : 'agent -t'
  end

  # Validate that our private key matches the specified certificate.
  #
  # @param [Puppet::SSL::Certificate] cert the certificate to check
  # @raises [Puppet::Error] if the private key does not match
  def validate_certificate_with_key(cert)
    raise Puppet::Error, _("No certificate to validate.") unless cert
    raise Puppet::Error, _("No private key with which to validate certificate with fingerprint: %{fingerprint}") % { fingerprint: cert.fingerprint } unless key
    unless cert.content.check_private_key(key.content)
      raise Puppet::Error, _(<<ERROR_STRING) % { fingerprint: cert.fingerprint, cert_name: Puppet[:certname], clean_params: clean_params, puppet_params: puppet_params }
The certificate retrieved from the master does not match the agent's private key. Did you forget to run as root?
Certificate fingerprint: %{fingerprint}
To fix this, remove the certificate from both the master and the agent and then start a puppet run, which will automatically regenerate a certificate.
On the master:
  puppetserver ca clean --certname %{cert_name}
On the agent:
  1. puppet ssl clean %{clean_params}
  2. puppet %{puppet_params}
ERROR_STRING
    end
  end

  def download_host_certificate
    cert = download_certificate_from_ca(name)
    return nil unless cert

    validate_certificate_with_key(cert)
    save_host_certificate(cert)
    cert
  end

  # Search for an existing CSR for this host either cached on
  # disk or stored by the CA. Returns nil if no request exists.
  # @return [Puppet::SSL::CertificateRequest, nil]
  def certificate_request
    unless @certificate_request
      csr = load_certificate_request_from_file
      if csr
        @certificate_request = csr
      else
        csr = download_csr_from_ca
        if csr 
          @certificate_request = csr
        end
      end
    end
    @certificate_request
  end

  # Generate all necessary parts of our ssl host.
  def generate
    generate_key unless key

    existing_request = certificate_request

    # if CSR downloaded from master, but the local keypair was just generated and
    # does not match the public key in the CSR, fail hard
    validate_csr_with_key(existing_request, key) if existing_request

    generate_certificate_request unless existing_request
  end

  def validate_csr_with_key(csr, key)
    if key.content.public_key.to_s != csr.content.public_key.to_s
      raise Puppet::Error, _(<<ERROR_STRING) % { fingerprint: csr.fingerprint, csr_public_key: csr.content.public_key.to_text, agent_public_key: key.content.public_key.to_text, cert_name: Puppet[:certname], clean_params: clean_params, puppet_params: puppet_params }
The CSR retrieved from the master does not match the agent's public key.
CSR fingerprint: %{fingerprint}
CSR public key: %{csr_public_key}
Agent public key: %{agent_public_key}
To fix this, remove the CSR from both the master and the agent and then start a puppet run, which will automatically regenerate a CSR.
On the master:
  puppetserver ca clean --certname %{cert_name}
On the agent:
  1. puppet ssl clean %{clean_params}
  2. puppet %{puppet_params}
ERROR_STRING
    end
  end
  private :validate_csr_with_key

  def initialize(name = nil, device = false)
    @name = (name || Puppet[:certname]).downcase
    @device = device
    Puppet::SSL::Base.validate_certname(@name)
    @key = @certificate = @certificate_request = nil
    @crl_usage = Puppet.settings[:certificate_revocation]
    @crl_path = Puppet.settings[:hostcrl]
  end

  # Extract the public key from the private key.
  def public_key
    key.content.public_key
  end

  def use_crl?
    !!@crl_usage
  end

  def use_crl_chain?
    @crl_usage == true || @crl_usage == :chain
  end

  # Create/return a store that uses our SSL info to validate
  # connections.
  def ssl_store(purpose = OpenSSL::X509::PURPOSE_ANY)
    if @ssl_store.nil?
      @ssl_store = build_ssl_store(purpose)
    end
    @ssl_store
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

  # Saves the given certificate to disc, at a location determined by this
  # host's configuration.
  # @param [Puppet::SSL::Certificate] cert the cert to save
  def save_host_certificate(cert)
    file_path = certificate_location(name)
    Puppet::Util.replace_file(file_path, 0644) do |f|
      f.write(cert.to_s)
    end
  end

  private

  # Load a previously generated CSR from disk
  # @return [Puppet::SSL::CertificateRequest, nil]
  def load_certificate_request_from_file
    request_path = certificate_request_location(name)
    if Puppet::FileSystem.exist?(request_path)
      Puppet::SSL::CertificateRequest.from_s(Puppet::FileSystem.read(request_path))
    end
  end

  # Download the CSR for this host from the CA. Returns nil if the CA
  # has no saved CSR for this host.
  # @raises [Puppet::Error] if the response from the server is not a valid
  #                         CSR or an error occurs while fetching.
  # @return [Puppet::SSL::CertificateRequest, nil]
  def download_csr_from_ca
    begin
      body = Puppet::Rest::Routes.get_certificate_request(
                    name, Puppet::SSL::SSLContext.new(store: ssl_store))
      begin
        Puppet::SSL::CertificateRequest.from_s(body)
      rescue OpenSSL::X509::RequestError => e
        raise Puppet::Error, _("Response from the CA did not contain a valid certificate request: %{message}") % { message: e.message }
      end
    rescue Puppet::Rest::ResponseError => e
      if e.response.code.to_i == 404
        nil
      else
        raise Puppet::Error, _('Could not download certificate request: %{message}') % { message: e.message }
      end
    end
  end
  # Submit the CSR to the CA via an HTTP PUT request.
  # @param [Puppet::SSL::CertificateRequest] csr the request to submit
  def submit_certificate_request(csr)
    Puppet::Rest::Routes.put_certificate_request(
                  csr.render, name, Puppet::SSL::SSLContext.new(store: ssl_store))
  end

  def save_certificate_request(csr)
    Puppet::Util.replace_file(certificate_request_location(name), 0644) do |file|
      file.write(csr.render)
    end
  end

  # @param crl_string [String] CRLs read from disk or obtained from server
  # @return [Array<OpenSSL::X509::CRL>] CRLs from chain
  # @raise [Puppet::Error<OpenSSL::X509::CRLError>] if the CRL chain is malformed
  def process_crl_string(crl_string)
    delimiters = /-----BEGIN X509 CRL-----.*?-----END X509 CRL-----/m
    crl_string.scan(delimiters).map do |crl|
      begin
        OpenSSL::X509::CRL.new(crl)
      rescue OpenSSL::X509::CRLError => e
        raise Puppet::Error.new(
          _("Failed attempting to load CRL from %{crl_path}! The CRL below caused the error '%{error}':\n%{crl}" % {crl_path: crl_path, error: e.message, crl: crl}),
          e)
      end
    end
  end

  # @param path [String] Path to CRL Chain
  # @return [Array<OpenSSL::X509::CRL>] CRLs from chain
  # @raise [Puppet::Error<OpenSSL::X509::CRLError>] if the CRL chain is malformed
  def load_crls(path)
    crls_pems = Puppet::FileSystem.read(path, encoding: Encoding::UTF_8)
    process_crl_string(crls_pems)
  end

  # Fetches and saves the crl bundle from the CA server without validating
  # its contents. Takes an optional store to use with the http_client,
  # necessary for initial download of the CRL because `build_ssl_store`
  # calls this `download_and_save_crl_bundle`. If there is an error during
  # this downloading process, the file should not be replaced at all. This
  # streams the file directly to disk to avoid loading the entire CRL in memory.
  # @param [OpenSSL::X509::Store] store optional ssl_store to use with http_client
  # @raise [Puppet::Error<Puppet::Rest::ResponseError>] if bad response from server
  # @return nil
  def download_and_save_crl_bundle(store=nil)
    begin
      # If no SSL store was supplied, use this host's SSL store
      store ||= ssl_store
      Puppet::Util.replace_file(crl_path, 0644) do |file|
        result = Puppet::Rest::Routes.get_crls(CA_NAME, Puppet::SSL::SSLContext.new(store: store))
        file.write(result)
      end
    rescue Puppet::Rest::ResponseError => e
      raise Puppet::Error, _('Could not download CRLs: %{message}') % { message: e.message }
    end
  end

  # Attempts to load or fetch this host's certificate. Returns nil if
  # no certificate could be found.
  # @return [Puppet::SSL::Certificate, nil]
  def get_host_certificate
    cert = check_for_certificate_on_disk(name)
    if cert
      return cert
    else
      cert = download_certificate_from_ca(name)
      if cert
        save_host_certificate(cert)
        return cert
      else
        return nil
      end
    end
  end

  # Checks for the requested certificate on disc, at a location
  # determined by this host's configuration.
  # @name [String] name the name of the cert to look for
  # @raise [Puppet::Error] if contents of certificate file is invalid
  #                        and could not be loaded
  # @return [Puppet::SSL::Certificate, nil]
  def check_for_certificate_on_disk(cert_name)
    file_path = certificate_location(cert_name)
    if Puppet::FileSystem.exist?(file_path)
      begin
        Puppet::SSL::Certificate.from_s(Puppet::FileSystem.read(file_path))
      rescue OpenSSL::X509::CertificateError
        raise Puppet::Error, _("The certificate at %{file_path} is invalid. Could not load.") % { file_path: file_path }
      end
    end
  end
  public :check_for_certificate_on_disk

  # Attempts to download this host's certificate from the CA server.
  # Returns nil if the CA does not yet have a signed cert for this host.
  # @param [String] name then name of the cert to fetch
  # @raise [Puppet::Error] if response from the CA does not contain a valid
  #                        certificate
  # @return [Puppet::SSL::Certificate, nil]
  def download_certificate_from_ca(cert_name)
    begin
      cert = Puppet::Rest::Routes.get_certificate(
        cert_name,
        Puppet::SSL::SSLContext.new(store: ssl_store)
      )
      begin
        Puppet::SSL::Certificate.from_s(cert)
      rescue OpenSSL::X509::CertificateError
        raise Puppet::Error, _("Response from the CA did not contain a valid certificate for %{cert_name}.") % { cert_name: cert_name }
      end
    rescue Puppet::Rest::ResponseError => e
      if e.response.code.to_i == 404
        Puppet.debug _("No certificate for %{cert_name} on CA") % { cert_name: cert_name }
        nil
      else
        raise Puppet::Rest::ResponseError, _("Could not download host certificate: %{message}") % { message: e.message }
      end
    end
  end
  public :download_certificate_from_ca

  # Returns the file path for the named certificate, based on this host's
  # configuration.
  # @param [String] name the name of the cert to find
  # @return [String] file path to the cert's location
  def certificate_location(cert_name)
    cert_name == CA_NAME ? Puppet[:localcacert] : File.join(Puppet[:certdir], "#{cert_name}.pem")
  end

  # Returns the file path for the named CSR, based on this host's configuration.
  # @param [String] name the name of the CSR to find
  # @return [String] file path to the CSR's location
  def certificate_request_location(cert_name)
    File.join(Puppet[:requestdir], "#{cert_name}.pem")
  end

  # @param [OpenSSL::X509::PURPOSE_*] constant defining the kinds of certs
  #   this store can verify
  # @return [OpenSSL::X509::Store]
  # @raise [OpenSSL::X509::StoreError] if localcacert is malformed or non-existant
  # @raise [Puppet::Error] if the CRL chain is malformed
  # @raise [Errno::ENOENT] if the CRL does not exist on disk but use_crl? is true
  def build_ssl_store(purpose=OpenSSL::X509::PURPOSE_ANY)
    store = OpenSSL::X509::Store.new
    store.purpose = purpose

    # Use the file path here, because we don't want to cause
    # a lookup in the middle of setting our ssl connection.
    store.add_file(Puppet.settings[:localcacert])

    if use_crl?
      if !Puppet::FileSystem.exist?(crl_path)
        download_and_save_crl_bundle(store)
      end

      crls = load_crls(crl_path)

      flags = OpenSSL::X509::V_FLAG_CRL_CHECK
      if use_crl_chain?
        flags |= OpenSSL::X509::V_FLAG_CRL_CHECK_ALL
      end

      store.flags = flags
      crls.each {|crl| store.add_crl(crl) }
    end
    store
  end
end
