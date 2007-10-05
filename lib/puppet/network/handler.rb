require 'puppet/util/docs'
require 'puppet/util/subclass_loader'

module Puppet::Network
    # The base class for the different handlers.  The handlers are each responsible
    # for separate xmlrpc namespaces.
    class Handler
        extend Puppet::Util::Docs

        # This is so that the handlers can subclass just 'Handler', rather
        # then having to specify the full class path.
        Handler = self
        attr_accessor :server, :local

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

        # Set/Determine whether we're a client- or server-side handler.
        def self.side(side = nil)
            if side
                side = side.intern if side.is_a?(String)
                unless [:client, :server].include?(side)
                    raise ArgumentError, "Invalid side registration '%s' for %s" % [side, self.name]
                end
                @side = side
            else
                @side ||= :server
                return @side
            end
        end

        # Create an empty init method with the same signature.
        def initialize(hash = {})
        end

        def local?
            self.local
        end
    end
end

