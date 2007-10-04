# unlike the other client classes (again, this design sucks) this class
# is basically just a proxy class -- it calls its methods on the driver
# and that's about it
class Puppet::Network::Client::ProxyClient < Puppet::Network::Client
    def self.mkmethods
        interface = self.handler.interface
        namespace = interface.prefix


        interface.methods.each { |ary|
            method = ary[0]
            Puppet.debug "%s: defining %s.%s" % [self, namespace, method]
            define_method(method) { |*args|
                begin
                    @driver.send(method, *args)
                rescue XMLRPC::FaultException => detail
                    #Puppet.err "Could not call %s.%s: %s" %
                    #    [namespace, method, detail.faultString]
                    #raise NetworkClientError,
                    #    "XMLRPC Error: %s" % detail.faultString
                    raise NetworkClientError, detail.faultString
                end
            }
        }
    end
end

