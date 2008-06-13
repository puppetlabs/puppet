require 'puppet/indirector'

# Provide any attributes or functionality needed for indirected
# instances.
class Puppet::Indirector::Request
    attr_accessor :indirection_name, :key, :method, :options, :instance, :node, :ip, :authenticated

    # Is this an authenticated request?
    def authenticated?
        # Double negative, so we just get true or false
        ! ! authenticated
    end

    def initialize(indirection_name, method, key, options = {})
        options ||= {}
        raise ArgumentError, "Request options must be a hash, not %s" % options.class unless options.is_a?(Hash)

        @indirection_name, @method = indirection_name, method

        @options = options.inject({}) do |result, ary|
            param, value = ary
            if respond_to?(param.to_s + "=")
                send(param.to_s + "=", value)
            else
                result[param] = value
            end
            result
        end

        if key.is_a?(String) or key.is_a?(Symbol)
            @key = key
        else
            @instance = key
            @key = @instance.name
        end
    end

    # Look up the indirection based on the name provided.
    def indirection
        Puppet::Indirector::Indirection.instance(@indirection_name)
    end
end
