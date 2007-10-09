require 'puppet/indirector/yaml'

class Puppet::Indirector::Yaml::Configuration < Puppet::Indirector::Yaml
    desc "Store configurations as flat files, serialized using YAML."

    private

    # Override these, because yaml doesn't want to convert our self-referential
    # objects.  This is hackish, but eh.
    def from_yaml(text)
        if config = YAML.load(text)
            # We can't yaml-dump classes.
            #config.edgelist_class = Puppet::Relationship
            return config
        end
    end

    def to_yaml(config)
        # We can't yaml-dump classes.
        #config.edgelist_class = nil
        YAML.dump(config)
    end
end
