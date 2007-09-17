# An actual indirection.
class Puppet::Indirector::Indirection
    @@indirections = []

    # Clear all cached termini from all indirections.
    def self.clear_cache
        @@indirections.each { |ind| ind.clear_cache }
    end
    
    attr_accessor :name, :termini
    attr_reader :to

    # Clear our cached list of termini.
    # This is only used for testing.
    def clear_cache
        @termini.clear
    end

    # This is only used for testing.
    def delete
        @@indirections.delete(self) if @@indirections.include?(self)
    end

    def initialize(name, options = {})
        @name = name
        options.each do |name, value|
            begin
                send(name.to_s + "=", value)
            rescue NoMethodError
                raise ArgumentError, "%s is not a valid Indirection parameter" % name
            end
        end
        @termini = {}
        @@indirections << self
    end

    # Return the singleton terminus for this indirection.
    def terminus(name = nil)
        # Get the name of the terminus.
        unless name
            unless param_name = self.to
                raise ArgumentError, "You must specify an indirection terminus for indirection %s" % self.name
            end
            name = Puppet[param_name]
            name = name.intern if name.is_a?(String)
        end
        
        unless @termini[name]
            @termini[name] = make_terminus(name)
        end
        @termini[name]
    end

    # Validate the parameter.  This requires that indirecting
    # classes require 'puppet/defaults', because of ordering issues,
    # but it makes problems much easier to debug.
    def to=(param_name)
        unless Puppet.config.valid?(param_name)
            raise ArgumentError, "Configuration parameter '%s' for indirection '%s' does not exist'" % [param_name, self.name]
        end
        @to = param_name
    end

    private

    # Create a new terminus instance.
    def make_terminus(name)
        # Load our terminus class.
        unless klass = Puppet::Indirector.terminus(self.name, name)
            raise ArgumentError, "Could not find terminus %s for indirection %s" % [name, self.name]
        end
        return klass.new
    end
end
