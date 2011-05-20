require 'puppet/indirector/face'
require 'puppet/node/facts'

Puppet::Indirector::Face.define(:facts, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Retrieve, store, and view facts."
  notes <<-EOT
    This is an indirector face, which exposes find, search, save, and
    destroy actions for an indirected subsystem of Puppet. Valid terminuses
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

  action(:upload) do
    summary "Upload our facts to the puppet master."
    description <<-EOT
      Retrieves facts for the local system and saves them to the puppet master
      server. This is essentially a shortcut action: it calls the `find`
      action with the facter terminus, then passes the returned facts object
      to the `save` action, which uses the rest terminus.
    EOT
    notes <<-EOT
      This action uses the save action, which requires the puppet master's
      auth.conf to allow save access to the `facts` REST terminus. See
      `http://docs.puppetlabs.com/guides/rest_auth_conf.html` for more details.
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
