# Just to make the constants work out.
require 'puppet'
require 'puppet/ssl/openssl_loader'

# Responsible for bootstrapping an agent's certificate and private key, generating
# SSLContexts for use in making HTTPS connections, and handling CSR attributes and
# certificate extensions.
#
# @see Puppet::SSL::SSLProvider
# @api private
module Puppet::SSL
  CA_NAME = "ca".freeze

  require 'puppet/ssl/oids'
  require 'puppet/ssl/error'
  require 'puppet/ssl/ssl_context'
  require 'puppet/ssl/verifier'
  require 'puppet/ssl/ssl_provider'
  require 'puppet/ssl/state_machine'
  require 'puppet/ssl/certificate'
  require 'puppet/ssl/certificate_request'
  require 'puppet/ssl/certificate_request_attributes'
end
