require 'puppet/indirector/yaml'

class Puppet::Indirector::Yaml::Configuration < Puppet::Indirector::Yaml
    desc "Store configurations as flat files, serialized using YAML."
end
