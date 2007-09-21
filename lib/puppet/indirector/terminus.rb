require 'puppet/indirector'

# A simple class that can function as the base class for indirected types.
class Puppet::Indirector::Terminus
    require 'puppet/util/docs'
    extend Puppet::Util::Docs
    
    class << self
        attr_accessor :name, :indirection
    end
    
    def name
        self.class.name
    end

    def indirection
        self.class.indirection
    end
end
