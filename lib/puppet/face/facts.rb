require 'puppet/face/indirector'
require 'puppet/node/facts'

Puppet::Face::Indirector.define(:facts, '0.0.1') do
  summary "Retrieve, store, and view facts."

  action(:upload) do
    summary "upload our facts to the server."

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
