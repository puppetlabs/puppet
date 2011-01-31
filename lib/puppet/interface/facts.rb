require 'puppet/interface'

class Puppet::Interface::Facts < Puppet::Interface
  # Upload our facts to the server
  action(:upload) do |*args|
    Puppet::Node::Facts.indirection.terminus_class = :facter
    Puppet::Node::Facts.indirection.cache_class = :rest
    Puppet::Node::Facts.indirection.find(Puppet[:certname])
  end
end
