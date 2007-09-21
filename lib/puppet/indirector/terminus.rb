require 'puppet/indirector'
require 'puppet/indirector/indirection'

# A simple class that can function as the base class for indirected types.
class Puppet::Indirector::Terminus
    require 'puppet/util/docs'
    extend Puppet::Util::Docs
    
    class << self
        attr_accessor :name
        attr_reader :indirection

        # Look up the indirection if we were only provided a name.
        def indirection=(name)
            if name.is_a?(Puppet::Indirector::Indirection)
                @indirection = name
            elsif ind = Puppet::Indirector::Indirection.instance(name)
                @indirection = ind
            else
                raise ArgumentError, "Could not find indirection instance %s" % name
            end
        end
    end

    def initialize
        unless indirection
            raise Puppet::DevError, "Indirection termini cannot be used without an associated indirection"
        end
    end
    
    def name
        self.class.name
    end

    def indirection
        self.class.indirection
    end
end
