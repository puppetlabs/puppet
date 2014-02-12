require 'puppet/node'
require 'puppet/indirector/msgpack'

class Puppet::Node::Msgpack < Puppet::Indirector::Msgpack
  desc "Store node information as flat files, serialized using MessagePack,
    or deserialize stored MessagePack nodes."
end
