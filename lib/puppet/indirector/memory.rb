require 'puppet/indirector/terminus'

# Manage a memory-cached list of instances.
class Puppet::Indirector::Memory < Puppet::Indirector::Terminus
    def initialize
        @instances = {}
    end

    def destroy(name)
        raise ArgumentError.new("Could not find %s to destroy" % name) unless @instances.include?(name)
        @instances.delete(name)
    end

    def find(name)
        @instances[name]
    end

    def save(instance)
        @instances[instance.name] = instance
    end
end
