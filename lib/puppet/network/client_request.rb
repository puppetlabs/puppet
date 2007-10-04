module Puppet::Network # :nodoc:
    # A struct-like class for passing around a client request.  It's mostly
    # just used for validation and authorization.
    class ClientRequest
        attr_accessor :name, :ip, :authenticated, :handler, :method

        def authenticated?
            self.authenticated
        end

        # A common way of talking about the full call.  Individual servers
        # are responsible for setting the values correctly, but this common
        # format makes it possible to check rights.
        def call
            unless handler and method
                raise ArgumentError, "Request is not set up; cannot build call"
            end

            [handler, method].join(".")
        end

        def initialize(name, ip, authenticated)
            @name, @ip, @authenticated = name, ip, authenticated
        end

        def to_s
            "%s(%s)" % [self.name, self.ip]
        end
    end
end

