require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:resource, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact directly with resources via the RAL, like ralsh"
end
