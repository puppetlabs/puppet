require 'puppet/indirector'

# Provide any attributes or functionality needed for indirected
# instances.
class Puppet::Indirector::Request
    attr_accessor :indirection_name, :key, :method, :options, :instance

    def initialize(indirection_name, method, key, options = {})
        @indirection_name, @method, @options = indirection_name, method, (options || {})

        if key.is_a?(String) or key.is_a?(Symbol)
            @key = key
        else
            @instance = key
            @key = @instance.name
        end

        raise ArgumentError, "Request options must be a hash, not %s" % @options.class unless @options.is_a?(Hash)
    end

    # Look up the indirection based on the name provided.
    def indirection
        Puppet::Indirector::Indirection.instance(@indirection_name)
    end
end
