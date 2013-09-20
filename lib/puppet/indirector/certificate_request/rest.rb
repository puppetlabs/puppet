require 'puppet/ssl/certificate_request'
require 'puppet/indirector/rest'

class Puppet::SSL::CertificateRequest::Rest < Puppet::Indirector::REST
  desc "Find and save certificate requests over HTTP via REST."

  use_server_setting(:ca_server)
  use_port_setting(:ca_port)
  use_srv_service(:ca)
end
