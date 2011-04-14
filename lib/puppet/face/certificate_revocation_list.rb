require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:certificate_revocation_list, '0.0.1') do
  summary "Manage the list of revoked certificates."
end
