require 'openssl'

# API for certificate verification
#
# @api public
class Puppet::SSL::Validator

  # Factory method for creating an instance of a null/no validator.
  # This method does not have to be implemented by concrete implementations of this API.
  #
  # @return [Puppet::SSL::Validator] produces a validator that performs no validation
  #
  # @api public
  #
  def self.no_validator()
    @@no_validator_cache ||= Puppet::SSL::Validator::NoValidator.new()
  end

  # Factory method for creating an instance of the default Puppet validator.
  # This method does not have to be implemented by concrete implementations of this API.
  #
  # @return [Puppet::SSL::Validator] produces a validator that performs no validation
  #
  # @api public
  #
  def self.default_validator()
    Puppet::SSL::Validator::DefaultValidator.new()
  end

  # Array of peer certificates
  # @return [Array<Puppet::SSL::Certificate>] peer certificates
  #
  # @api public
  #
  def peer_certs
    raise NotImplementedError, "Concrete class should have implemented this method"
  end

  # Contains the result of validation
  # @return [Array<String>, nil] nil, empty Array, or Array with messages
  #
  # @api public
  #
  def verify_errors
    raise NotImplementedError, "Concrete class should have implemented this method"
  end

  # Registers the connection to validate.
  #
  # @param [Net::HTTP] connection The connection to validate
  #
  # @return [void]
  #
  # @api public
  #
  def setup_connection(connection)
    raise NotImplementedError, "Concrete class should have implemented this method"
  end
end

