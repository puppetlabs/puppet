# Allows a `Puppet::SSL::Validator` to be used in situations where an
# `Verifier` is required, while preserving the legacy validator behavior of:
#
# * Loading CA certs from `ssl_client_ca_auth` or `localcacert`
# * Verifying each cert in the peer's chain is contained in the file
#   loaded above.
#
class Puppet::SSL::VerifierAdapter
  def initialize(validator)
    @validator = validator
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
    Puppet::Util::SSL.handle_connection_error(error, @validator, http.address)
  end
end
