require 'puppet/indirector/yaml'

class Puppet::Indirector::Yaml::Node < Puppet::Indirector::Yaml
    desc "Store node information as flat files, serialized using YAML."
end
