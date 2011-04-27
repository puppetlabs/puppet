require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:resource_type, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View resource types, classes, and nodes from all manifests"
  description "TK I have no idea what this does."
  notes <<-EOT
This is an indirector face, which exposes find, search, save, and
destroy actions for an indirected subsystem of Puppet. Valid terminuses
for this face include:

* `parser`
* `rest`
  EOT
end
