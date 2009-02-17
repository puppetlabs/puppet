# Model the environment that a node can operate in.  This class just
# provides a simple wrapper for the functionality around environments.
class Puppet::Node::Environment
    @seen = {}

    # Return an existing environment instance, or create a new one.
    def self.new(name = nil)
        name ||= Puppet.settings.value(:environment)

        raise ArgumentError, "Environment name must be specified" unless name

        symbol = name.to_sym

        return @seen[symbol] if @seen[symbol]

        obj = self.allocate
        obj.send :initialize, symbol
        @seen[symbol] = obj
    end

    attr_reader :name

    # Return an environment-specific setting.
    def [](param)
        Puppet.settings.value(param, self.name)
    end

    def initialize(name)
        @name = name
    end

    def module(name)
        Puppet::Module.each_module(self[:modulepath]) do |mod|
            return mod if mod.name == name
        end

        return nil
    end

    # Return all modules from this environment.
    def modules
        result = []
        Puppet::Module.each_module(self[:modulepath]) do |mod|
            result << mod
        end
        result
    end
end
