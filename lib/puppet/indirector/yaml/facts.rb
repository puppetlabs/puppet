require 'puppet/indirector/yaml'

class Puppet::Indirector::Yaml::Facts < Puppet::Indirector::Yaml
    desc "Store client facts as flat files, serialized using YAML."
end
