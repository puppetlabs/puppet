require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:resource, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact directly with resources via the RAL, like ralsh"
  description <<-EOT
    This face provides a Ruby API with functionality similar to the puppet
    resource (née ralsh) command line application. It is not intended to be
    used from the command line.
  EOT
  notes <<-EOT
    This is an indirector face, which exposes find, search, save, and
    destroy actions for an indirected subsystem of Puppet. Valid terminuses
    for this face include:

    * `ral`
    * `rest`
  EOT

  examples "TK we really need some examples for this one."
end
