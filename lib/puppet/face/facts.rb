require 'puppet/indirector/face'
require 'puppet/node/facts'

Puppet::Indirector::Face.define(:facts, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Retrieve and store facts."
  description <<-'EOT'
    This subcommand manages facts, which are collections of normalized system
    information used by Puppet. It can read facts directly from the local system
    (with the default `facter` terminus).
  EOT

  find = get_action(:find)
  find.summary "Retrieve a node's facts."
  find.arguments "[<node_certname>]"
  find.returns <<-'EOT'
    A hash containing some metadata and (under the "values" key) the set
    of facts for the requested node. When used from the Ruby API: A
    Puppet::Node::Facts object.

    RENDERING ISSUES: Facts cannot currently be rendered as a string; use yaml
    or json.
  EOT
  find.notes <<-'EOT'
    When using the `facter` terminus, the host argument is ignored.
  EOT
  find.examples <<-'EOT'
    Get facts from the local system:

    $ puppet facts find
  EOT
  find.default = true

  deactivate_action(:destroy)
  deactivate_action(:search)
end
