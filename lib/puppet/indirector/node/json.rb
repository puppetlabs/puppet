require 'puppet/node'
require 'puppet/indirector/json'

class Puppet::Node::Json < Puppet::Indirector::JSON
  desc "Store node information as flat files, serialized using JSON,
    or deserialize stored JSON nodes."

end
