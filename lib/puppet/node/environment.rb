# Model the environment that a node can operate in.  This class just
# provides a simple wrapper for the functionality around environments.
class Puppet::Node::Environment
    # Return the list of valid environments.  Just looks them up in
    # the settings.
    def self.valid
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = Puppet.settings.value(:environments).split(",").collect { |e| e.to_sym }
    end

    # Is the provided environment valid?
    def self.valid?(name)
        return false if name.to_s == ""
        valid.include?(name.to_sym)
    end

    @seen = {}

    # Return an existing environment instance, or create a new one,
    # validating the environment name.
    def self.new(name = nil)
        name ||= Puppet.settings.value(:environment)

        raise ArgumentError, "Environment name must be specified" unless name

        raise(ArgumentError, "'%s' is not a valid environment" % name) unless valid?(name)

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
end
