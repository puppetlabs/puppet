require 'puppet/node'
require 'puppet/indirector/yaml'

class Puppet::Node::Yaml < Puppet::Indirector::Yaml
    desc "Store node information as flat files, serialized using YAML,
        or deserialize stored YAML nodes."
end
