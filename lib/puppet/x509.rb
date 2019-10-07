require 'puppet'
require 'puppet/ssl/openssl_loader'

module Puppet::X509 # :nodoc:
  require 'puppet/x509/pem_store'
  require 'puppet/x509/cert_provider'
end
