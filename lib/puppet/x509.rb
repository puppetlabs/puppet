require 'puppet'
require 'puppet/ssl/openssl_loader'

# Responsible for loading and saving certificates and private keys.
#
# @see Puppet::X509::CertProvider
# @api private
module Puppet::X509
  require 'puppet/x509/pem_store'
  require 'puppet/x509/cert_provider'
end
