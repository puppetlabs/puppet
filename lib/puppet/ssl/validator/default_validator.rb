require 'openssl'
require 'puppet/ssl'
require 'forwardable'

# @deprecated
class Puppet::SSL::Validator::DefaultValidator
  attr_reader :validator

  def initialize(_ssl_configuration = nil, _ssl_host = nil)
    Puppet.deprecation_warning("Puppet::SSL::Validator::DefaultValidator is deprecated. Use Puppet::SSL::Validator.cert_auth_validator if the host has a signed cert, or Puppet::SSL::Validator.best_validator if the host certificate signing status is unknown.")
  end

  # Generate a new validator every time we set up a new connection in case a
  # validator is reused between connection and the host SSL state has changed
  # between invocations.
  def setup_connection(connection)
    @validator = Puppet::SSL::Validator.best_validator
    @validator.setup_connection(connection)
  end

  extend Forwardable
  def_delegators :@validator, :peer_certs, :verify_errors, :ssl_configuration, :call
end
