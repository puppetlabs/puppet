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
    best_validator
  end

  # Select the best available validator, determined by what SSL files we have available.
  #
  # Because this method falls through to no validation it is inherently insecure. Since
  # Puppet bootstraps SSL right away there are very few cases where we should risk
  # downgrading our security level. In the cases where this downgrading is acceptable
  # then this can be used on a case by case basis, but otherwise use the cert_auth_validator.
  #
  # @api public
  def self.best_validator
    if Puppet::FileSystem.exist?(Puppet[:hostcert])
      cert_auth_validator
    elsif Puppet::FileSystem.exist?(Puppet[:localcacert])
      unauthenticated_validator
    else
      no_validator
    end
  end

  # Factory method for generating a validator instance that performs peer verification and
  # can perform cert based client authentication.
  #
  # @api public
  def self.cert_auth_validator
    Puppet::SSL::Validator::CertAuthValidator.new
  end

  # Factory method for generating a validator instance that performs peer verification but
  # does not perform cert based client authentication.
  #
  # @api public
  def self.unauthenticated_validator
    Puppet::SSL::Validator::UnauthenticatedValidator.new
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

