require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_revocation_list, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage the list of revoked certificates."
end
