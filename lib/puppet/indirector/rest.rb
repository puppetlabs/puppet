require 'puppet/indirector/rest'

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
    def find(name)
        indirection.model.new(name)
    end
end
