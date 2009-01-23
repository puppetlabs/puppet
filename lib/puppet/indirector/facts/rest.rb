require 'puppet/node/facts'
require 'puppet/indirector/rest'

class Puppet::Node::Facts::Rest < Puppet::Indirector::REST
    desc "Find and save certificates over HTTP via REST."
end
