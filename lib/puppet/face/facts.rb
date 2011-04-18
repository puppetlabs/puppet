require 'puppet/face/indirector'
require 'puppet/node/facts'

Puppet::Face::Indirector.define(:facts, '0.0.1') do
  # Upload our facts to the server
  action(:upload) do
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
