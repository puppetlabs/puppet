require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:certificate_request, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage certificate requests."
end
