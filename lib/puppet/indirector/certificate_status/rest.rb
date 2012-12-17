require 'puppet/ssl/host'
require 'puppet/indirector/rest'
require 'puppet/indirector/certificate_status'

class Puppet::Indirector::CertificateStatus::Rest < Puppet::Indirector::REST
  desc "Sign, revoke, search for, or clean certificates & certificate requests over HTTP."

  use_server_setting(:ca_server)
  use_port_setting(:ca_port)
  use_srv_service(:ca)
end
