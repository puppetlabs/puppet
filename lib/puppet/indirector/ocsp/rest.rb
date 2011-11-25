require 'puppet/indirector/ocsp'
require 'puppet/indirector/rest'

class Puppet::Indirector::Ocsp::Rest < Puppet::Indirector::REST
  desc "Remote OCSP certificate REST remote revocation status."

  use_server_setting(:ca_server)
  use_port_setting(:ca_port)

  # do not even try to verify the connection we use for ocsp_verification
  # otherwise we'll loop forever :)
  disable_ocsp_verification
end
