# Just to make the constants work out.
require 'puppet'
require 'openssl'

module Puppet::SSL # :nodoc:
  CA_NAME = "ca".freeze
  require 'puppet/ssl/host'
  require 'puppet/ssl/oids'
  require 'puppet/ssl/validator'
  require 'puppet/ssl/validator/no_validator'
  require 'puppet/ssl/validator/default_validator'
  require 'puppet/ssl/error'
  require 'puppet/ssl/ssl_context'
  require 'puppet/ssl/verifier'
  require 'puppet/ssl/verifier_adapter'
  require 'puppet/ssl/ssl_provider'
  require 'puppet/ssl/state_machine'
end
