require 'puppet/ssl/certificate_request'
require 'puppet/indirector/rest'

class Puppet::SSL::CertificateRequest::Rest < Puppet::Indirector::REST
    desc "Find and save certificate requests over HTTP via REST."
end
