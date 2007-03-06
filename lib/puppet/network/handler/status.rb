class Puppet::Network::Handler
    class Status < Handler
        @interface = XMLRPC::Service::Interface.new("status") { |iface|
            iface.add_method("int status()")
        }

        def status(client = nil, clientip = nil)
            return 1
        end
    end
end

# $Id$
