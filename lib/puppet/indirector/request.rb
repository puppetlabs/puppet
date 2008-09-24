require 'puppet/indirector'

# This class encapsulates all of the information you need to make an
# Indirection call, and as a a result also handles REST calls.  It's somewhat
# analogous to an HTTP Request object, except tuned for our Indirector.
class Puppet::Indirector::Request
    attr_accessor :indirection_name, :key, :method, :options, :instance, :node, :ip, :authenticated

    attr_accessor :server, :port, :uri, :protocol

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
            # If the request key is a URI, then we need to treat it specially,
            # because it rewrites the key.  We could otherwise strip server/port/etc
            # info out in the REST class, but it seemed bad design for the REST
            # class to rewrite the key.
            if key.to_s =~ /^\w+:\/\// # it's a URI
                set_uri_key(key)
            else
                @key = key
            end
        else
            @instance = key
            @key = @instance.name
        end
    end

    # Look up the indirection based on the name provided.
    def indirection
        Puppet::Indirector::Indirection.instance(@indirection_name)
    end

    # Are we trying to interact with multiple resources, or just one?
    def plural?
        method == :search
    end

    private

    # Parse the key as a URI, setting attributes appropriately.
    def set_uri_key(key)
        @uri = key
        begin
            uri = URI.parse(URI.escape(key))
        rescue => detail
            raise ArgumentError, "Could not understand URL %s: %s" % [source, detail.to_s]
        end

        # Just short-circuit these to full paths
        if uri.scheme == "file"
            @key = uri.path
            return
        end

        @server = uri.host if uri.host

        # If the URI class can look up the scheme, it will provide a port,
        # otherwise it will default to '0'.
        if uri.port.to_i == 0 and uri.scheme == "puppet"
            @port = Puppet.settings[:masterport].to_i
        else
            @port = uri.port.to_i
        end

        @protocol = uri.scheme
        @key = uri.path.sub(/^\//, '')
    end
end
