# Just to make the constants work out.
require 'puppet'
require 'openssl'

module Puppet::SSL # :nodoc:
  CA_NAME = "ca"
  require 'puppet/ssl/configuration'
  require 'puppet/ssl/host'
  require 'puppet/ssl/oids'
  require 'puppet/ssl/validator'
  require 'puppet/ssl/validator/no_validator'
  require 'puppet/ssl/validator/default_validator'
end
