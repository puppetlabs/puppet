require 'puppet/ssl/validator/unauthenticated_validator'

# Perform peer certificate verification and include the SSL host key pair and certificate for
# SSL client authentication.
#
# @api private
class Puppet::SSL::Validator::CertAuthValidator < Puppet::SSL::Validator::UnauthenticatedValidator

  # @param ssl_configuration [Puppet::SSL::Configuration]
  # @param ssl_host [Puppet::SSL::Host] The SSL host whose keys and certificate we should use for cert based authentication
  #
  # @api private
  def initialize(ssl_configuration = Puppet::SSL::Configuration.default, ssl_host = Puppet.lookup(:ssl_host))
    super(ssl_configuration)
    @ssl_host = ssl_host
  end

  def setup_connection(connection)
    super
    connection.cert = @ssl_host.certificate.content
    connection.key = @ssl_host.key.content
  end

  protected

  # Override the parent class's behavior and rely on the global
  # certificate_revocation setting.
  def ssl_store
    @ssl_configuration.ssl_store
  end
end
