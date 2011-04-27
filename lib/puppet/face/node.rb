require 'puppet/indirector/face'
Puppet::Indirector::Face.define(:node, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View and manage node definitions"

  description <<-EOT
This face interacts with node objects, which are what Puppet uses to build a catalog. A node object consists of the node's facts, environment, additional top-scope variables, and classes. TK need this fact-checked.
  EOT
  notes <<-EOT
This is an indirector face, which exposes find, search, save, and
destroy actions for an indirected subsystem of Puppet. Valid terminuses
for this face include:

* `active_record`
* `exec`
* `ldap`
* `memory`
* `plain`
* `rest`
* `yaml`
  EOT
end
