# frozen_string_literal: true

require_relative '../../../puppet/node'
require_relative '../../../puppet/indirector/yaml'

class Puppet::Node::Yaml < Puppet::Indirector::Yaml
  desc "Store node information as flat files, serialized using YAML,
    or deserialize stored YAML nodes."
end
