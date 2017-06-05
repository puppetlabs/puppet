require 'puppet/node'
require 'puppet/indirector/plain'

class Puppet::Node::Plain < Puppet::Indirector::Plain
  desc "Always return an empty node object. Assumes you keep track of nodes
    in flat file manifests.  You should use it when you don't have some other,
    functional source you want to use, as the compiler will not work without a
    valid node terminus.

    Note that class is responsible for merging the node's facts into the
    node instance before it is returned."

  # Just return an empty node.
  def find(request)
    node = super
    node.environment = request.environment
    facts = request.options[:facts].is_a?(Puppet::Node::Facts) ? request.options[:facts] : nil
    node.fact_merge(facts)
    node
  end
end
