class Puppet::Network::Handler
    class Status < Handler
        desc "A simple interface for testing Puppet connectivity."

        side :client

        @interface = XMLRPC::Service::Interface.new("status") { |iface|
            iface.add_method("int status()")
        }

        def status(client = nil, clientip = nil)
            return 1
        end
    end
end

