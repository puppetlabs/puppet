require 'puppet/node/facts'
require 'puppet/indirector/yaml'

class Puppet::Node::Facts::Yaml < Puppet::Indirector::Yaml
    desc "Store client facts as flat files, serialized using YAML, or
        return deserialized facts from disk."
end
