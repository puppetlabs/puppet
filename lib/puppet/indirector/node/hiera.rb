require 'hiera'
require 'puppet/node'
require 'puppet/indirector/hiera'

class Puppet::Node::Hiera < Puppet::Indirector::Hiera
  desc 'Get node information from Hiera. Queries the keys "environment", "classes" and "parameters".'

  def find(request)
    facts = Puppet::Node::Facts.indirection.find(request.key)
    node = Puppet::Node.new(
      request.key,
      :environment => hiera.lookup('environment', request.environment.name.to_s, facts.values),
      :parameters  => hiera.lookup('parameters', {}, facts.values, nil, :hash),
      :classes     => hiera.lookup('classes', [], facts.values, nil, :array)
    )
    node.fact_merge
    node
  end
end
