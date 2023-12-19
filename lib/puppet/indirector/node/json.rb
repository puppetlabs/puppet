# frozen_string_literal: true

require_relative '../../../puppet/node'
require_relative '../../../puppet/indirector/json'

class Puppet::Node::Json < Puppet::Indirector::JSON
  desc "Store node information as flat files, serialized using JSON,
    or deserialize stored JSON nodes."
end
