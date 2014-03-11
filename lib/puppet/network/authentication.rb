require 'puppet/ssl/certificate_authority'
require 'puppet/util/log/rate_limited_logger'

# Place for any authentication related bits
module Puppet::Network::Authentication
  # Create a rate-limited logger for the expiration warning that uses the run interval
  # as the minimum amount of time before a warning about the same cert can be logged again.
  # This is a class variable so that all classes that include the module share the same logger.
  @@logger = Puppet::Util::Log::RateLimitedLogger.new(Puppet[:runinterval])

  # Check the expiration of known certificates and optionally any that are specified as part of a request
  def warn_if_near_expiration(*certs)
    # Check CA cert if we're functioning as a CA
    certs << Puppet::SSL::CertificateAuthority.instance.host.certificate if Puppet::SSL::CertificateAuthority.ca?

    # Depending on the run mode, the localhost certificate will be for the
    # master or the agent. Don't load the certificate if the CA cert is not
    # present: infinite recursion will occur as another authenticated request
    # will be spawned to download the CA cert.
    if [Puppet[:hostcert], Puppet[:localcacert]].all? {|path| Puppet::FileSystem.exist?(path) }
      certs << Puppet::SSL::Host.localhost.certificate
    end

    # Remove nil values for caller convenience
    certs.compact.each do |cert|
      # Allow raw OpenSSL certificate instances or Puppet certificate wrappers to be specified
      cert = Puppet::SSL::Certificate.from_instance(cert) if cert.is_a?(OpenSSL::X509::Certificate)
      raise ArgumentError, "Invalid certificate '#{cert.inspect}'" unless cert.is_a?(Puppet::SSL::Certificate)

      if cert.near_expiration?
        @@logger.warning("Certificate '#{cert.unmunged_name}' will expire on #{cert.expiration.strftime('%Y-%m-%dT%H:%M:%S%Z')}")
      end
    end
  end
end
