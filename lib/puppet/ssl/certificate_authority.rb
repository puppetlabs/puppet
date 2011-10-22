require 'monitor'
require 'puppet/ssl/host'
require 'puppet/ssl/certificate_request'

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
  require 'puppet/network/authstore'

  extend MonitorMixin

  class CertificateVerificationError < RuntimeError
    attr_accessor :error_code

    def initialize(code)
      @error_code = code
    end
  end

  def self.singleton_instance
    synchronize do
      @singleton_instance ||= new
    end
  end

  class CertificateSigningError < RuntimeError
    attr_accessor :host

    def initialize(host)
      @host = host
    end
  end

  def self.ca?
    return false unless Puppet[:ca]
    return false unless Puppet.run_mode.master?
    true
  end

  # If this process can function as a CA, then return a singleton
  # instance.
  def self.instance
    return nil unless ca?

    singleton_instance
  end

  attr_reader :name, :host

  # Create and run an applicator.  I wanted to build an interface where you could do
  # something like 'ca.apply(:generate).to(:all) but I don't think it's really possible.
  def apply(method, options)
    raise ArgumentError, "You must specify the hosts to apply to; valid values are an array or the symbol :all" unless options[:to]
    applier = Interface.new(method, options)
    applier.apply(self)
  end

  # If autosign is configured, then autosign all CSRs that match our configuration.
  def autosign
    return unless auto = autosign?

    store = nil
    store = autosign_store(auto) if auto != true

    Puppet::SSL::CertificateRequest.indirection.search("*").each do |csr|
      sign(csr.name) if auto == true or store.allowed?(csr.name, "127.1.1.1")
    end
  end

  # Do we autosign?  This returns true, false, or a filename.
  def autosign?
    auto = Puppet[:autosign]
    return false if ['false', false].include?(auto)
    return true if ['true', true].include?(auto)

    raise ArgumentError, "The autosign configuration '#{auto}' must be a fully qualified file" unless auto =~ /^\//
    FileTest.exist?(auto) && auto
  end

  # Create an AuthStore for autosigning.
  def autosign_store(file)
    auth = Puppet::Network::AuthStore.new
    File.readlines(file).each do |line|
      next if line =~ /^\s*#/
      next if line =~ /^\s*$/
      auth.allow(line.chomp)
    end

    auth
  end

  # Retrieve (or create, if necessary) the certificate revocation list.
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

  # Delegate this to our Host class.
  def destroy(name)
    Puppet::SSL::Host.destroy(name)
  end

  # Generate a new certificate.
  def generate(name, options = {})
    raise ArgumentError, "A Certificate already exists for #{name}" if Puppet::SSL::Certificate.indirection.find(name)
    host = Puppet::SSL::Host.new(name)

    # Pass on any requested subjectAltName field.
    san = options[:dns_alt_names]

    host = Puppet::SSL::Host.new(name)
    host.generate_certificate_request(:dns_alt_names => san)
    sign(name, !!san)
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
    @certificate = sign(host.name, false, request)

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
      Puppet.settings.write(:capass) { |f| f.print pass }
    rescue Errno::EACCES => detail
      raise Puppet::Error, "Could not write CA password: #{detail}"
    end

    @password = pass

    pass
  end

  # List all signed certificates.
  def list
    Puppet::SSL::Certificate.indirection.search("*").collect { |c| c.name }
  end

  # Read the next serial from the serial file, and increment the
  # file so this one is considered used.
  def next_serial
    serial = nil

    # This is slightly odd.  If the file doesn't exist, our readwritelock creates
    # it, but with a mode we can't actually read in some cases.  So, use
    # a default before the lock.
    serial = 0x1 unless FileTest.exist?(Puppet[:serial])

    Puppet.settings.readwritelock(:serial) { |f|
      serial ||= File.read(Puppet.settings[:serial]).chomp.hex if FileTest.exist?(Puppet[:serial])

      # We store the next valid serial, not the one we just used.
      f << "%04X" % (serial + 1)
    }

    serial
  end

  # Does the password file exist?
  def password?
    FileTest.exist? Puppet[:capass]
  end

  # Print a given host's certificate as text.
  def print(name)
    (cert = Puppet::SSL::Certificate.indirection.find(name)) ? cert.to_text : nil
  end

  # Revoke a given certificate.
  def revoke(name)
    raise ArgumentError, "Cannot revoke certificates when the CRL is disabled" unless crl

    if cert = Puppet::SSL::Certificate.indirection.find(name)
      serial = cert.content.serial
    elsif ! serial = inventory.serial(name)
      raise ArgumentError, "Could not find a serial number for #{name}"
    end
    crl.revoke(serial, host.key.content)
  end

  # This initializes our CA so it actually works.  This should be a private
  # method, except that you can't any-instance stub private methods, which is
  # *awesome*.  This method only really exists to provide a stub-point during
  # testing.
  def setup
    generate_ca_certificate unless @host.certificate
  end

  # Sign a given certificate request.
  def sign(hostname, allow_dns_alt_names = false, self_signing_csr = nil)
    # This is a self-signed certificate
    if self_signing_csr
      # # This is a self-signed certificate, which is for the CA.  Since this
      # # forces the certificate to be self-signed, anyone who manages to trick
      # # the system into going through this path gets a certificate they could
      # # generate anyway.  There should be no security risk from that.
      csr = self_signing_csr
      cert_type = :ca
      issuer = csr.content
    else
      allow_dns_alt_names = true if hostname == Puppet[:certname].downcase
      unless csr = Puppet::SSL::CertificateRequest.indirection.find(hostname)
        raise ArgumentError, "Could not find certificate request for #{hostname}"
      end

      cert_type = :server
      issuer = host.certificate.content

      # Make sure that the CSR conforms to our internal signing policies.
      # This will raise if the CSR doesn't conform, but just in case...
      check_internal_signing_policies(hostname, csr, allow_dns_alt_names) or
        raise CertificateSigningError.new(hostname), "CSR had an unknown failure checking internal signing policies, will not sign!"
    end

    cert = Puppet::SSL::Certificate.new(hostname)
    cert.content = Puppet::SSL::CertificateFactory.
      build(cert_type, csr, issuer, next_serial)
    cert.content.sign(host.key.content, OpenSSL::Digest::SHA1.new)

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

  def check_internal_signing_policies(hostname, csr, allow_dns_alt_names)
    # Reject unknown request extensions.
    unknown_req = csr.request_extensions.
      reject {|x| RequestExtensionWhitelist.include? x["oid"] }

    if unknown_req and not unknown_req.empty?
      names = unknown_req.map {|x| x["oid"] }.sort.uniq.join(", ")
      raise CertificateSigningError.new(hostname), "CSR has request extensions that are not permitted: #{names}"
    end

    # Wildcards: we don't allow 'em at any point.
    #
    # The stringification here makes the content visible, and saves us having
    # to scrobble through the content of the CSR subject field to make sure it
    # is what we expect where we expect it.
    if csr.content.subject.to_s.include? '*'
      raise CertificateSigningError.new(hostname), "CSR subject contains a wildcard, which is not allowed: #{csr.content.subject.to_s}"
    end

    unless csr.subject_alt_names.empty?
      # If you alt names are allowed, they are required. Otherwise they are
      # disallowed. Self-signed certs are implicitly trusted, however.
      unless allow_dns_alt_names
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

  # Verify a given host's certificate.
  def verify(name)
    unless cert = Puppet::SSL::Certificate.indirection.find(name)
      raise ArgumentError, "Could not find a certificate for #{name}"
    end
    store = OpenSSL::X509::Store.new
    store.add_file Puppet[:cacert]
    store.add_crl crl.content if self.crl
    store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
    store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK if Puppet.settings[:certificate_revocation]

    raise CertificateVerificationError.new(store.error), store.error_string unless store.verify(cert.content)
  end

  def fingerprint(name, md = :MD5)
    unless cert = Puppet::SSL::Certificate.indirection.find(name) || Puppet::SSL::CertificateRequest.indirection.find(name)
      raise ArgumentError, "Could not find a certificate or csr for #{name}"
    end
    cert.fingerprint(md)
  end

  # List the waiting certificate requests.
  def waiting?
    Puppet::SSL::CertificateRequest.indirection.search("*").collect { |r| r.name }
  end
end
