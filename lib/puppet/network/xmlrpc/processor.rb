require 'puppet/network/authorization'
require 'xmlrpc/server'

# Just silly.
class ::XMLRPC::FaultException
    def to_s
        self.message
    end
end

module Puppet::Network
    # Most of our subclassing is just so that we can get
    # access to information from the request object, like
    # the client name and IP address.
    module XMLRPCProcessor
        include Puppet::Network::Authorization

        ERR_UNAUTHORIZED = 30

        def add_handler(interface, handler)
            @loadedhandlers << interface.prefix
            super(interface, handler)
        end

        def handler_loaded?(handler)
            @loadedhandlers.include?(handler.to_s)
        end

        # Convert our data and client request into xmlrpc calls, and verify
        # they're authorized and such-like.  This method differs from the
        # default in that it expects a ClientRequest object in addition to the
        # data.
        def process(data, request)
            call, params = parser().parseMethodCall(data)
            params << request.name << request.ip
            handler, method = call.split(".")
            request.handler = handler
            request.method = method
            begin
                verify(request)
            rescue InvalidClientRequest => detail
                raise ::XMLRPC::FaultException.new(ERR_UNAUTHORIZED, detail.to_s)
            end
            handle(request.call, *params)
        end

        private

        # Provide error handling for method calls.
        def protect_service(obj, *args)
            begin
                obj.call(*args)
            rescue ::XMLRPC::FaultException
                raise
            rescue Puppet::AuthorizationError => detail
                Puppet.err "Permission denied: %s" % detail.to_s
                raise ::XMLRPC::FaultException.new(
                    1, detail.to_s
                )
            rescue Puppet::Error => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                Puppet.err detail.to_s
                error = ::XMLRPC::FaultException.new(
                    1, detail.to_s
                )
                error.set_backtrace detail.backtrace
                raise error
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                Puppet.err "Could not call: %s" % detail.to_s
                error = ::XMLRPC::FaultException.new(1, detail.to_s)
                error.set_backtrace detail.backtrace
                raise error
            end
        end

        # Set up our service hook and init our handler list.
        def setup_processor
            @loadedhandlers = []
            self.set_service_hook do |obj, *args|
                protect_service(obj, *args)
            end
        end
    end
end

