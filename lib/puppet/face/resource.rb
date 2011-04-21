require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:resource, '0.0.1') do
  summary "Interact directly with resources via the RAL, like ralsh"
end
