require 'puppet/ssl/certificate_revocation_list'
require 'puppet/indirector/rest'

class Puppet::SSL::CertificateRevocationList::Rest < Puppet::Indirector::REST
  desc "Find and save certificate revocation lists over HTTP via REST."

  use_server_setting(:ca_server)
  use_port_setting(:ca_port)
  use_srv_service(:ca)

  def find(request)
    if !Puppet::FileSystem.exist?(Puppet[:hostcrl])
      msg =  "Disable certificate revocation checking when fetching the CRL and no CRL is present"
      overrides = {certificate_revocation: false}
      Puppet.override(overrides, msg) do
        super
      end
    else
      super
    end
  end
end
