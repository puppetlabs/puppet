require 'puppet/interface/indirector'
require 'puppet/node/facts'

Puppet::Interface::Indirector.new(:facts) do
  set_default_format :yaml

  # Upload our facts to the server
  action(:upload) do |*args|
    Puppet::Node::Facts.indirection.terminus_class = :facter
    Puppet::Node::Facts.indirection.cache_class = :rest
    Puppet::Node::Facts.indirection.find(Puppet[:certname])
  end
end
