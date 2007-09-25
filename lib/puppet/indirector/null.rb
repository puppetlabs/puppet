require 'puppet/indirector/terminus'

# An empty terminus type, meant to just return empty objects.
class Puppet::Indirector::Null < Puppet::Indirector::Terminus
    # Just return nothing.
    def find(name)
        indirection.model.new(name)
    end
end
