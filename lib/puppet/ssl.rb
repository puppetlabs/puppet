# Just to make the constants work out.
require_relative '../puppet'
require_relative '../puppet/ssl/openssl_loader'

# Responsible for bootstrapping an agent's certificate and private key, generating
# SSLContexts for use in making HTTPS connections, and handling CSR attributes and
# certificate extensions.
#
# @see Puppet::SSL::SSLProvider
# @api private
module Puppet::SSL
  CA_NAME = "ca".freeze

  require_relative '../puppet/ssl/oids'
  require_relative '../puppet/ssl/error'
  require_relative '../puppet/ssl/ssl_context'
  require_relative '../puppet/ssl/verifier'
  require_relative '../puppet/ssl/ssl_provider'
  require_relative '../puppet/ssl/state_machine'
  require_relative '../puppet/ssl/certificate'
  require_relative '../puppet/ssl/certificate_request'
  require_relative '../puppet/ssl/certificate_request_attributes'
end
