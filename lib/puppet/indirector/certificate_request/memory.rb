require 'puppet/ssl/certificate_request'
require 'puppet/indirector/memory'

class Puppet::SSL::CertificateRequest::Memory < Puppet::Indirector::Memory
  desc "Store certificate requests in memory. This is used for testing puppet."
end
