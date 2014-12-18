require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:resource_type, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View classes, defined resource types, and nodes from all manifests."
  description <<-'EOT'
    This subcommand reads information about the resource collections (classes,
    nodes, and defined types) available in Puppet's site manifest and
    modules.

    It will eventually be extended to examine native resource types.
  EOT
  notes <<-'EOT'
    The `find` and `search` actions return similar hashes of resource collection
    info. These hashes will include the following four keys:

    * `file` (a string)
    * `name` (a string)
    * `type` (<hostclass>, <definition>, or <node>)
    * `line` (an integer)

    They may optionally include the following keys:

    * `parent`    (<name_of_resource_collection>)
    * `arguments` (a hash of parameters and default values)
    * `doc`       (a string)
  EOT

  deactivate_action(:save)
  deactivate_action(:destroy)

  find = get_action(:find)
  find.summary "Retrieve info about a resource collection."
  find.arguments "<collection_name>"
  find.returns <<-'EOT'
    A hash of info about the requested resource collection. When used from the
    Ruby API: returns a Puppet::Resource::Type object.

    RENDERING ISSUES: yaml and string output for this indirection are currently
    unusable; use json instead.
  EOT
  find.notes <<-'EOT'
    If two resource collections share the same name (e.g. you have both a node
    and a class named "default"), `find` will only return one of them. This can
    be worked around by using `search` instead.
  EOT
  find.examples <<-'EOT'
    Retrieve info about a specific locally-defined class:

    $ puppet resource_type find ntp::disabled

    Retrieve info from the puppet master about a specific class:

    $ puppet resource_type find ntp --terminus rest
  EOT
  # For this face we don't want to default to the certname like other indirector
  # based faces. Instead we want the user to always supply a argument.
  find.when_invoked = Proc.new do |key, options|
    call_indirection_method :find, key, options[:extra]
  end

  search = get_action(:search)
  search.summary "Search for collections matching a regular expression."
  search.arguments "<regular_expression>"
  search.returns <<-'EOT'
    An array of hashes of resource collection info. When used from the Ruby API:
    returns an array of Puppet::Resource::Type objects.

    RENDERING ISSUES: yaml and string output for this indirection are currently
    unusable; use json instead.
  EOT
  search.examples <<-'EOT'
    Retrieve all classes, nodes, and defined types:

    $ puppet resource_type search '.*'

    Search for classes related to Nagios:

    $ puppet resource_type search nagios
  EOT

end
