# frozen_string_literal: true

require_relative '../puppet'
require_relative '../puppet/ssl/openssl_loader'

# Responsible for loading and saving certificates and private keys.
#
# @see Puppet::X509::CertProvider
# @api private
module Puppet::X509
  require_relative 'x509/pem_store'
  require_relative 'x509/cert_provider'
end
