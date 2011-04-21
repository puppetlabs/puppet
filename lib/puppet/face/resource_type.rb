require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:resource_type, '0.0.1') do
  summary "View resource types, classes, and nodes from all manifests"
end
