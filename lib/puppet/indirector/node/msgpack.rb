# frozen_string_literal: true

require_relative '../../../puppet/node'
require_relative '../../../puppet/indirector/msgpack'

class Puppet::Node::Msgpack < Puppet::Indirector::Msgpack
  desc "Store node information as flat files, serialized using MessagePack,
    or deserialize stored MessagePack nodes."
end
