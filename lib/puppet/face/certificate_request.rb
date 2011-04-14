require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:certificate_request, '0.0.1') do
  summary "Manage certificate requests."
end
