require 'puppet/node'
require 'puppet/indirector/rest'

class Puppet::Node::Rest < Puppet::Indirector::REST
  desc "Get a node via REST. Puppet agent uses this to allow the puppet master
    to override its environment."
end
