# Just to make the constants work out.
require 'puppet'
require 'openssl'

module Puppet::SSL # :nodoc:
  CA_NAME = "ca"
  require 'puppet/ssl/host'
end
