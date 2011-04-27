require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:resource_type, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View resource types, classes, and nodes from all manifests"
end
