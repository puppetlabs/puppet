require 'puppet/indirector/face'
Puppet::Indirector::Face.define(:node, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View and manage node definitions."
  description <<-'EOT'
    This face interacts with node objects, which are used by Puppet to
    build a catalog. A node object consists of the node's facts,
    environment, node parameters (exposed in the parser as top-scope
    variables), and classes.
  EOT

  get_action(:destroy).summary "Invalid for this face."
  get_action(:search).summary "Invalid for this face."
  get_action(:save).summary "Invalid for this face."

  find = get_action(:find)
  find.summary "Retrieve a node object."
  find.arguments "<host>"
  find.returns <<-'EOT'
    A Puppet::Node object.

    RENDERING ISSUES: Rendering as string and json are currently broken;
    node objects can only be rendered as yaml.
  EOT
  find.examples <<-'EOT'
    Retrieve an "empty" (no classes, fact and bulit-in parameters only,
    and an environment of "production") node:

    $ puppet node find somenode.puppetlabs.lan --terminus plain --render-as yaml

    Retrieve a node using the puppet master's configured ENC:

    $ puppet node find somenode.puppetlabs.lan --terminus exec --mode master --render-as yaml
  EOT
end
