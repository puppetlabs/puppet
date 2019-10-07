# Allows a `Puppet::SSL::Validator` to be used in situations where a
# `Verifier` is required, while preserving the legacy validator behavior of:
#
# * Loading CA certs from `ssl_client_ca_auth` or `localcacert`
# * Verifying each cert in the peer's chain is contained in the file
#   loaded above.
#
class Puppet::SSL::VerifierAdapter
  attr_reader :validator

  def initialize(validator)
    @validator = validator
  end

  # Return true if `self` is reusable with `verifier` meaning they
  # are both using the same class of `Puppet::SSL::Validator`. In this
  # case we only care the Validator class is the same. We can't require
  # the same instances, because a new instance is created each time
  # HttpPool.http_instance is called.
  #
  # @param verifier [Puppet::SSL::Verifier] the verifier to compare against
  # @return [Boolean] return true if a cached connection can be used, false otherwise
  def reusable?(verifier)
    verifier.instance_of?(self.class) &&
      verifier.validator.instance_of?(@validator.class)
  end

  # Configure the `http` connection based on the current `ssl_context`.
  #
  # @param http [Net::HTTP] connection
  # @api private
  def setup_connection(http)
    @validator.setup_connection(http)
  end

  # Handle an SSL connection error.
  #
  # @param http [Net::HTTP] connection
  # @param error [OpenSSL::SSL::SSLError] connection error
  # @return (see Puppet::SSL::Verifier#handle_connection_error)
  # @raise [Puppet::SSL::CertVerifyError] SSL connection failed due to a
  #   verification error with the server's certificate or chain
  # @raise [Puppet::Error] server hostname does not match certificate
  # @raise [OpenSSL::SSL::SSLError] low-level SSL connection failure
  def handle_connection_error(http, error)
    raise @validator.last_error if @validator.respond_to?(:last_error) && @validator.last_error

    Puppet::Util::SSL.handle_connection_error(error, @validator, http.address)
  end
end
