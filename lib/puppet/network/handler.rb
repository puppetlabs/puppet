require 'puppet/util/subclass_loader'

module Puppet::Network
    # The base class for the different handlers.  The handlers are each responsible
    # for separate xmlrpc namespaces.
    class Handler
        # This is so that the handlers can subclass just 'Handler', rather
        # then having to specify the full class path.
        Handler = self
        attr_accessor :server

        extend Puppet::Util::SubclassLoader
        extend Puppet::Util

        handle_subclasses :handler, "puppet/network/handler"

        # Return the xmlrpc interface.
        def self.interface
            if defined? @interface
                return @interface
            else
                raise Puppet::DevError, "Handler %s has no defined interface" %
                    self
            end
        end

        # Create an empty init method with the same signature.
        def initialize(hash = {})
        end
    end
end

# $Id$
