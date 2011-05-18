require 'puppet/indirector/face'
require 'puppet/node/facts'

Puppet::Indirector::Face.define(:facts, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Retrieve and store facts."
  description <<-'EOT'
    This face manages facts, the collections of normalized system
    information used by Puppet. It can read facts directly from the
    local system (using the default `facter` terminus), look up facts
    reported by other systems, and submit facts to the puppet master.

    When used with the `rest` terminus, this face is essentially a
    front-end to the inventory service REST API. See the inventory
    service documentation for more detail.
  EOT
  notes <<-'EOT'
    This is an indirector face, which exposes `find`, `search`, `save`, and
    `destroy` actions for an indirected subsystem of Puppet. Valid termini
    for this face include:

    * `active_record`
    * `couch`
    * `facter`
    * `inventory_active_record`
    * `memory`
    * `network_device`
    * `rest`
    * `yaml`
  EOT

  find = get_action(:find)
  find.summary "Retrieve a host's facts."
  find.arguments "<host>"
  find.returns "A Puppet::Node::Facts object."
  find.notes <<-'EOT'
    When using the `facter` terminus, the host argument is essentially ignored.
  EOT
  find.examples <<-'EOT'
    Get facts from the local system:

    $ puppet facts find x

    Ask the puppet master for facts for an arbitrary node:

    $ puppet facts find somenode.puppetlabs.lan --terminus rest

    Query a DB-backed inventory directly (bypassing the REST API):

    $ puppet facts find somenode.puppetlabs.lan --terminus inventory_active_record --mode master
  EOT

  get_action(:destroy).summary "Invalid for this face."
  get_action(:search).summary "Query format unknown; potentially invalid for this face."

  action(:upload) do
    summary "Upload local facts to the puppet master."
    description <<-'EOT'
      Reads facts from the local system using the facter terminus, then
      saves the returned facts using the rest terminus.
    EOT
    returns "Nothing."
    notes <<-'EOT'
      This action requires that the puppet master's `auth.conf` file
      allow save access to the `facts` REST terminus. Puppet agent does
      not use this facility, and it is turned off by default. See
      <http://docs.puppetlabs.com/guides/rest_auth_conf.html> for more details.
    EOT
    examples <<-'EOT'
      Upload facts:

      $ puppet facts upload
    EOT

    render_as :yaml

    when_invoked do |options|
      Puppet::Node::Facts.indirection.terminus_class = :facter
      facts = Puppet::Node::Facts.indirection.find(Puppet[:certname])
      Puppet::Node::Facts.indirection.terminus_class = :rest
      Puppet::Node::Facts.indirection.save(facts)
      Puppet.notice "Uploaded facts for '#{Puppet[:certname]}'"
      nil
    end
  end
end
