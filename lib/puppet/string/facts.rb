require 'puppet/string/indirector'
require 'puppet/node/facts'

Puppet::String::Indirector.define(:facts, '0.0.1') do
  set_default_format :yaml

  # Upload our facts to the server
  action(:upload) do
    invoke do |*args|
      Puppet::Node::Facts.indirection.terminus_class = :facter
      facts = Puppet::Node::Facts.indirection.find(Puppet[:certname])
      Puppet::Node::Facts.indirection.terminus_class = :rest
      Puppet::Node::Facts.indirection.save(facts)
      Puppet.notice "Uploaded facts for '#{Puppet[:certname]}'"
      nil
    end
  end
end
