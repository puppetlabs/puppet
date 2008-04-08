require 'puppet/indirector/terminus'

# Manage a memory-cached list of instances.
class Puppet::Indirector::Memory < Puppet::Indirector::Terminus
    def initialize
        @instances = {}
    end

    def destroy(request)
        raise ArgumentError.new("Could not find %s to destroy" % request.key) unless @instances.include?(request.key)
        @instances.delete(request.key)
    end

    def find(request)
        @instances[request.key]
    end

    def save(request)
        @instances[request.key] = request.instance
    end
end
