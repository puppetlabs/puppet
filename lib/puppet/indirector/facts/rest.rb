require 'puppet/node/facts'
require 'puppet/indirector/rest'

class Puppet::Node::Facts::Rest < Puppet::Indirector::REST
    desc "Find and save facts about nodes over HTTP via REST."
end
