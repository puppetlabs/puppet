require 'xmlrpc/server'
require 'puppet/network/authorization'
require 'puppet/network/xmlrpc/processor'

module Puppet::Network
    # Most of our subclassing is just so that we can get
    # access to information from the request object, like
    # the client name and IP address.
    class XMLRPCServer < ::XMLRPC::BasicServer
        include Puppet::Util
        include Puppet::Network::XMLRPCProcessor

        def initialize
            super()
            setup_processor()
        end
    end
end

