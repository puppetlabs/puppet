require 'puppet/network/client'

# Request a certificate from the remote system.
class Puppet::Network::Client::CA < Puppet::Network::Client
  class InvalidCertificate < Puppet::Error; end

  def initialize(options = {})
    options = symbolize_options(options)
    unless options.include?(:Server) or options.include?(:CA)
      options[:Server] = Puppet[:ca_server]
      options[:Port] = Puppet[:ca_port]
    end
    super(options)
  end

  # This client is really only able to request certificates for the
  # current host.  It uses the Puppet.settings settings to figure everything out.
  def request_cert
    Puppet.settings.use(:main, :ssl)

    if cert = read_cert
      return cert
    end

    begin
      cert, cacert = @driver.getcert(csr.to_pem)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      raise Puppet::Error.new("Certificate retrieval failed: #{detail}")
    end

    if cert.nil? or cert == ""
      return nil
    end

    begin
      @cert = OpenSSL::X509::Certificate.new(cert)
      @cacert = OpenSSL::X509::Certificate.new(cacert)
    rescue => detail
      raise InvalidCertificate.new(
        "Invalid certificate: #{detail}"
      )
    end

    unless @cert.check_private_key(key)
      raise InvalidCertificate, "Certificate does not match private key.  Try 'puppetca --clean #{Puppet[:certname]}' on the server."
    end

    # Only write the cert out if it passes validating.
    Puppet.settings.write(:hostcert) do |f| f.print cert end
    Puppet.settings.write(:localcacert) do |f| f.print cacert end

    @cert
  end
end

