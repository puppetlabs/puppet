require 'puppet/ssl/certificate_revocation_list'
require 'puppet/indirector/rest'

class Puppet::SSL::CertificateRevocationList::Rest < Puppet::Indirector::REST
  desc "Find and save certificate revocation lists over HTTP via REST."

  use_server_setting(:ca_server)
  use_port_setting(:ca_port)
  use_srv_service(:ca)
end
