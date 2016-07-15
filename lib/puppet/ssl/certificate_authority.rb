require 'puppet/ssl/host'
require 'puppet/ssl/certificate_request'
require 'puppet/ssl/certificate_signer'
require 'puppet/util'

# The class that knows how to sign certificates.  It creates
# a 'special' SSL::Host whose name is 'ca', thus indicating
# that, well, it's the CA.  There's some magic in the
# indirector/ssl_file terminus base class that does that
# for us.
#   This class mostly just signs certs for us, but
# it can also be seen as a general interface into all of the
# SSL stuff.
class Puppet::SSL::CertificateAuthority
  # We will only sign extensions on this whitelist, ever.  Any CSR with a
  # requested extension that we don't recognize is rejected, against the risk
  # that it will introduce some security issue through our ignorance of it.
  #
  # Adding an extension to this whitelist simply means we will consider it
  # further, not that we will always accept a certificate with an extension
  # requested on this list.
  RequestExtensionWhitelist = %w{subjectAltName}

  require 'puppet/ssl/certificate_factory'
  require 'puppet/ssl/inventory'
  require 'puppet/ssl/certificate_revocation_list'
  require 'puppet/ssl/certificate_authority/interface'
  require 'puppet/ssl/certificate_authority/autosign_command'
  require 'puppet/network/authstore'

  class CertificateVerificationError < RuntimeError
    attr_accessor :error_code

    def initialize(code)
      @error_code = code
    end
  end

  def self.singleton_instance
    @singleton_instance ||= new
  end

  class CertificateSigningError < RuntimeError
    attr_accessor :host

    def initialize(host)
      @host = host
    end
  end

  def self.ca?
    # running as ca? - ensure boolean answer
    !!(Puppet[:ca] && Puppet.run_mode.master?)
  end

  # If this process can function as a CA, then return a singleton instance.
  def self.instance
    ca? ? singleton_instance : nil
  end

  attr_reader :name, :host

  # If autosign is configured, autosign the csr we are passed.
  # @param csr [Puppet::SSL::CertificateRequest] The csr to sign.
  # @return [Void]
  # @api private
  def autosign(csr)
    if autosign?(csr)
      Puppet.info "Autosigning #{csr.name}"
      sign(csr.name)
    end
  end

  # Determine if a CSR can be autosigned by the autosign store or autosign command
  #
  # @param csr [Puppet::SSL::CertificateRequest] The CSR to check
  # @return [true, false]
  # @api private
  def autosign?(csr)
    auto = Puppet[:autosign]

    decider = case auto
      when false
        AutosignNever.new
      when true
        AutosignAlways.new
      else
        file = Puppet::FileSystem.pathname(auto)
        if Puppet::FileSystem.executable?(file)
          Puppet::SSL::CertificateAuthority::AutosignCommand.new(auto)
        elsif Puppet::FileSystem.exist?(file)
          AutosignConfig.new(file)
        else
          AutosignNever.new
        end
      end

    decider.allowed?(csr)
  end

  # Retrieves (or creates, if necessary) the certificate revocation list.
  def crl
    unless defined?(@crl)
      unless @crl = Puppet::SSL::CertificateRevocationList.indirection.find(Puppet::SSL::CA_NAME)
        @crl = Puppet::SSL::CertificateRevocationList.new(Puppet::SSL::CA_NAME)
        @crl.generate(host.certificate.content, host.key.content)
        Puppet::SSL::CertificateRevocationList.indirection.save(@crl)
      end
    end
    @crl
  end

  # Delegates this to our Host class.
  def destroy(name)
    Puppet::SSL::Host.destroy(name)
  end

  # Generates a new certificate.
  # @return Puppet::SSL::Certificate
  def generate(name, options = {})
    raise ArgumentError, "A Certificate already exists for #{name}" if Puppet::SSL::Certificate.indirection.find(name)

    # Pass on any requested subjectAltName field.
    san = options[:dns_alt_names]

    host = Puppet::SSL::Host.new(name)
    host.generate_certificate_request(:dns_alt_names => san)
    # CSR may have been implicitly autosigned, generating a certificate
    # Or sign explicitly
    host.certificate || sign(name, {allow_dns_alt_names: !!san})
  end

  # Generate our CA certificate.
  def generate_ca_certificate
    generate_password unless password?

    host.generate_key unless host.key

    # Create a new cert request.  We do this specially, because we don't want
    # to actually save the request anywhere.
    request = Puppet::SSL::CertificateRequest.new(host.name)

    # We deliberately do not put any subjectAltName in here: the CA
    # certificate absolutely does not need them. --daniel 2011-10-13
    request.generate(host.key)

    # Create a self-signed certificate.
    @certificate = sign(host.name, {allow_dns_alt_names: false,
                                    self_signing_csr: request})

    # And make sure we initialize our CRL.
    crl
  end

  def initialize
    Puppet.settings.use :main, :ssl, :ca

    @name = Puppet[:certname]

    @host = Puppet::SSL::Host.new(Puppet::SSL::Host.ca_name)

    setup
  end

  # Retrieve (or create, if necessary) our inventory manager.
  def inventory
    @inventory ||= Puppet::SSL::Inventory.new
  end

  # Generate a new password for the CA.
  def generate_password
    pass = ""
    20.times { pass += (rand(74) + 48).chr }

    begin
      Puppet.settings.setting(:capass).open('w') { |f| f.print pass }
    rescue Errno::EACCES => detail
      raise Puppet::Error, "Could not write CA password: #{detail}", detail.backtrace
    end

    @password = pass

    pass
  end

  # Lists the names of all signed certificates.
  #
  # @param name [Array<string>] filter to cerificate names
  #
  # @return [Array<String>]
  def list(name='*')
    list_certificates(name).collect { |c| c.name }
  end

  # Return all the certificate objects as found by the indirector
  # API for PE license checking.
  #
  # Created to prevent the case of reading all certs from disk, getting
  # just their names and verifying the cert for each name, which then
  # causes the cert to again be read from disk.
  #
  # @author Jeff Weiss <jeff.weiss@puppetlabs.com>
  # @api Puppet Enterprise Licensing
  #
  # @param name [Array<string>] filter to cerificate names
  #
  # @return [Array<Puppet::SSL::Certificate>]
  def list_certificates(name='*')
    Puppet::SSL::Certificate.indirection.search(name)
  end

  # Read the next serial from the serial file, and increment the
  # file so this one is considered used.
  def next_serial
    serial = 1
    Puppet.settings.setting(:serial).exclusive_open('a+') do |f|
      f.rewind
      serial = f.read.chomp.hex
      if serial == 0
        serial = 1
      end

      f.truncate(0)
      f.rewind

      # We store the next valid serial, not the one we just used.
      f << "%04X" % (serial + 1)
    end

    serial
  end

  # Does the password file exist?
  def password?
    Puppet::FileSystem.exist?(Puppet[:capass])
  end

  # Print a given host's certificate as text.
  def print(name)
    (cert = Puppet::SSL::Certificate.indirection.find(name)) ? cert.to_text : nil
  end

  # Revoke a given certificate.
  def revoke(name)
    raise ArgumentError, "Cannot revoke certificates when the CRL is disabled" unless crl

    cert = Puppet::SSL::Certificate.indirection.find(name)

    serials = if cert
                [cert.content.serial]
              elsif name =~ /^0x[0-9A-Fa-f]+$/
                [name.hex]
              else
                inventory.serials(name)
              end

    if serials.empty?
      raise ArgumentError, "Could not find a serial number for #{name}"
    end

    serials.each do |s|
      crl.revoke(s, host.key.content)
    end
  end

  # This initializes our CA so it actually works.  This should be a private
  # method, except that you can't any-instance stub private methods, which is
  # *awesome*.  This method only really exists to provide a stub-point during
  # testing.
  def setup
    generate_ca_certificate unless @host.certificate
  end

  # Sign a given certificate request.
  def sign(hostname, options={})
    options[:allow_authorization_extensions] ||= false
    options[:allow_dns_alt_names] ||= false
    options[:self_signing_csr] ||= nil

    self_signing_csr = options.delete(:self_signing_csr)

    if self_signing_csr
      # # This is a self-signed certificate, which is for the CA.  Since this
      # # forces the certificate to be self-signed, anyone who manages to trick
      # # the system into going through this path gets a certificate they could
      # # generate anyway.  There should be no security risk from that.
      csr = self_signing_csr
      cert_type = :ca
      issuer = csr.content
    else
      unless csr = Puppet::SSL::CertificateRequest.indirection.find(hostname)
        raise ArgumentError, "Could not find certificate request for #{hostname}"
      end

      cert_type = :server
      issuer = host.certificate.content

      # Make sure that the CSR conforms to our internal signing policies.
      # This will raise if the CSR doesn't conform, but just in case...
      check_internal_signing_policies(hostname, csr, options) or
        raise CertificateSigningError.new(hostname), "CSR had an unknown failure checking internal signing policies, will not sign!"
    end

    cert = Puppet::SSL::Certificate.new(hostname)
    cert.content = Puppet::SSL::CertificateFactory.
      build(cert_type, csr, issuer, next_serial)

    signer = Puppet::SSL::CertificateSigner.new
    signer.sign(cert.content, host.key.content)

    Puppet.notice "Signed certificate request for #{hostname}"

    # Add the cert to the inventory before we save it, since
    # otherwise we could end up with it being duplicated, if
    # this is the first time we build the inventory file.
    inventory.add(cert)

    # Save the now-signed cert.  This should get routed correctly depending
    # on the certificate type.
    Puppet::SSL::Certificate.indirection.save(cert)

    # And remove the CSR if this wasn't self signed.
    Puppet::SSL::CertificateRequest.indirection.destroy(csr.name) unless self_signing_csr

    cert
  end

  def check_internal_signing_policies(hostname, csr, options = {})
    options[:allow_authorization_extensions] ||= false
    options[:allow_dns_alt_names] ||= false
    # This allows for masters to bootstrap themselves in certain scenarios
    options[:allow_dns_alt_names] = true if hostname == Puppet[:certname].downcase

    # Reject unknown request extensions.
    unknown_req = csr.request_extensions.reject do |x|
      RequestExtensionWhitelist.include? x["oid"] or
        Puppet::SSL::Oids.subtree_of?('ppRegCertExt', x["oid"], true) or
        Puppet::SSL::Oids.subtree_of?('ppPrivCertExt', x["oid"], true) or
        Puppet::SSL::Oids.subtree_of?('ppAuthCertExt', x["oid"], true)
    end

    if unknown_req and not unknown_req.empty?
      names = unknown_req.map {|x| x["oid"] }.sort.uniq.join(", ")
      raise CertificateSigningError.new(hostname), "CSR has request extensions that are not permitted: #{names}"
    end

    # Do not sign misleading CSRs
    cn = csr.content.subject.to_a.assoc("CN")[1]
    if hostname != cn
      raise CertificateSigningError.new(hostname), "CSR subject common name #{cn.inspect} does not match expected certname #{hostname.inspect}"
    end

    if hostname !~ Puppet::SSL::Base::VALID_CERTNAME
      raise CertificateSigningError.new(hostname), "CSR #{hostname.inspect} subject contains unprintable or non-ASCII characters"
    end

    # Wildcards: we don't allow 'em at any point.
    #
    # The stringification here makes the content visible, and saves us having
    # to scrobble through the content of the CSR subject field to make sure it
    # is what we expect where we expect it.
    if csr.content.subject.to_s.include? '*'
      raise CertificateSigningError.new(hostname), "CSR subject contains a wildcard, which is not allowed: #{csr.content.subject.to_s}"
    end

    unless csr.content.verify(csr.content.public_key)
      raise CertificateSigningError.new(hostname), "CSR contains a public key that does not correspond to the signing key"
    end

    auth_extensions = csr.request_extensions.select do |extension|
      Puppet::SSL::Oids.subtree_of?('ppAuthCertExt', extension['oid'], true)
    end

    if auth_extensions.any? && !options[:allow_authorization_extensions]
      ext_names = auth_extensions.map do |extension|
        extension['oid']
      end

      raise CertificateSigningError.new(hostname), "CSR '#{csr.name}' contains authorization extensions (#{ext_names.join(', ')}), which are disallowed by default. Use `puppet cert --allow-authorization-extensions sign #{csr.name}` to sign this request."
    end

    unless csr.subject_alt_names.empty?
      # If you alt names are allowed, they are required. Otherwise they are
      # disallowed. Self-signed certs are implicitly trusted, however.
      unless options[:allow_dns_alt_names]
        raise CertificateSigningError.new(hostname), "CSR '#{csr.name}' contains subject alternative names (#{csr.subject_alt_names.join(', ')}), which are disallowed. Use `puppet cert --allow-dns-alt-names sign #{csr.name}` to sign this request."
      end

      # If subjectAltNames are present, validate that they are only for DNS
      # labels, not any other kind.
      unless csr.subject_alt_names.all? {|x| x =~ /^DNS:/ }
        raise CertificateSigningError.new(hostname), "CSR '#{csr.name}' contains a subjectAltName outside the DNS label space: #{csr.subject_alt_names.join(', ')}.  To continue, this CSR needs to be cleaned."
      end

      # Check for wildcards in the subjectAltName fields too.
      if csr.subject_alt_names.any? {|x| x.include? '*' }
        raise CertificateSigningError.new(hostname), "CSR '#{csr.name}' subjectAltName contains a wildcard, which is not allowed: #{csr.subject_alt_names.join(', ')}  To continue, this CSR needs to be cleaned."
      end
    end

    return true                 # good enough for us!
  end

  # Utility method for optionally caching the X509 Store for verifying a
  # large number of certificates in a short amount of time--exactly the
  # case we have during PE license checking.
  #
  # @example Use the cached X509 store
  #   x509store(:cache => true)
  #
  # @example Use a freshly create X509 store
  #   x509store
  #   x509store(:cache => false)
  #
  # @param [Hash] options the options used for retrieving the X509 Store
  # @option options [Boolean] :cache whether or not to use a cached version
  #   of the X509 Store
  #
  # @return [OpenSSL::X509::Store]
  def x509_store(options = {})
    if (options[:cache])
      return @x509store unless @x509store.nil?
      @x509store = create_x509_store
    else
      create_x509_store
    end
  end
  private :x509_store

  # Creates a brand new OpenSSL::X509::Store with the appropriate
  # Certificate Revocation List and flags
  #
  # @return [OpenSSL::X509::Store]
  def create_x509_store
    store = OpenSSL::X509::Store.new()
    store.add_file(Puppet[:cacert])
    store.add_crl(crl.content) if self.crl
    store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
    if Puppet.settings[:certificate_revocation]
      store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL | OpenSSL::X509::V_FLAG_CRL_CHECK
    end
    store
  end
  private :create_x509_store

  # Utility method which is API for PE license checking.
  # This is used rather than `verify` because
  #  1) We have already read the certificate from disk into memory.
  #     To read the certificate from disk again is just wasteful.
  #  2) Because we're checking a large number of certificates against
  #     a transient CertificateAuthority, we can relatively safely cache
  #     the X509 Store that actually does the verification.
  #
  # Long running instances of CertificateAuthority will certainly
  # want to use `verify` because it will recreate the X509 Store with
  # the absolutely latest CRL.
  #
  # Additionally, this method explicitly returns a boolean whereas
  # `verify` will raise an error if the certificate has been revoked.
  #
  # @author Jeff Weiss <jeff.weiss@puppetlabs.com>
  # @api Puppet Enterprise Licensing
  #
  # @param cert [Puppet::SSL::Certificate] the certificate to check validity of
  #
  # @return [Boolean] true if signed, false if unsigned or revoked
  def certificate_is_alive?(cert)
    x509_store(:cache => true).verify(cert.content)
  end

  # Verify a given host's certificate. The certname is passed in, and
  # the indirector will be used to locate the actual contents of the
  # certificate with that name.
  #
  # @param name [String] certificate name to verify
  #
  # @raise [ArgumentError] if the certificate name cannot be found
  #   (i.e. doesn't exist or is unsigned)
  # @raise [CertificateVerficationError] if the certificate has been revoked
  #
  # @return [Boolean] true if signed, there are no cases where false is returned
  def verify(name)
    unless cert = Puppet::SSL::Certificate.indirection.find(name)
      raise ArgumentError, "Could not find a certificate for #{name}"
    end
    store = x509_store

    raise CertificateVerificationError.new(store.error), store.error_string unless store.verify(cert.content)
  end

  def fingerprint(name, md = :SHA256)
    unless cert = Puppet::SSL::Certificate.indirection.find(name) || Puppet::SSL::CertificateRequest.indirection.find(name)
      raise ArgumentError, "Could not find a certificate or csr for #{name}"
    end
    cert.fingerprint(md)
  end

  # List the waiting certificate requests.
  def waiting?
    Puppet::SSL::CertificateRequest.indirection.search("*").collect { |r| r.name }
  end

  # @api private
  class AutosignAlways
    def allowed?(csr)
      true
    end
  end

  # @api private
  class AutosignNever
    def allowed?(csr)
      false
    end
  end

  # @api private
  class AutosignConfig
    def initialize(config_file)
      @config = config_file
    end

    def allowed?(csr)
      autosign_store.allowed?(csr.name, '127.1.1.1')
    end

    private

    def autosign_store
      auth = Puppet::Network::AuthStore.new
      Puppet::FileSystem.each_line(@config) do |line|
        next if line =~ /^\s*#/
        next if line =~ /^\s*$/
        auth.allow(line.chomp)
      end

      auth
    end
  end
end
