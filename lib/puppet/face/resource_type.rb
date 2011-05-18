require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:resource_type, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View classes, defined resource types, and nodes from all manifests"
  description <<-'EOT'
    This face reads information about the resource collections (classes,
    nodes, and defined types) available in Puppet's site manifest and
    modules.

    It will eventually be extended to examine native resource types.
  EOT
  notes <<-'EOT'
    This is an indirector face, which exposes `find`, `search`, `save`, and
    `destroy` actions for an indirected subsystem of Puppet. Valid termini
    for this face include:

    * `parser`
    * `rest`
  EOT

  # Action documentation overrides:
  get_action(:save).summary = "Invalid for this face."
  get_action(:destroy).summary = "Invalid for this face."

  find = get_action(:find)
  find.summary "Retrieve info about a resource collection."
  find.arguments "<collection_name>"
  find.returns <<-'EOT'
    A hash of info about one resource collection. This hash will include the
    following four keys:

    * `file` (a string)
    * `name` (a string)
    * `type` (<hostclass>, <definition>, or <node>)
    * `line` (an integer)

    It may also include the following keys:

    * `parent`    (<name_of_resource_collection>)
    * `arguments` (a hash of parameters and default values)
    * `doc`       (a string)

    RENDERING ISSUES: yaml and string output for this indirection are
    currently unusable; use json instead.
  EOT
  find.examples <<-'EOT'
    Retrieve info about a specific locally-defined class:

    $ puppet resource_type find ntp::disabled

    Retrieve info from the puppet master about a specific class:

    $ puppet resource_type find ntp --terminus rest
  EOT

  search = get_action(:search)
  search.summary "Search for collections matching a regular expression."
  search.arguments "<regular_expression>"
  search.returns <<-'EOT'
    An array of resource collection info hashes. (See "RETURNS" under `find`.)

    RENDERING ISSUES: yaml and string output for this indirection are
    currently unusable; use json instead.
  EOT
  search.examples <<-'EOT'
    Retrieve all classes, nodes, and defined types:

    $ puppet resource_type search '.*'

    Search for classes related to Nagios:

    $ puppet resource_type search nagios
  EOT

end
