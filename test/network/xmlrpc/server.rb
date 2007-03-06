#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/xmlrpc/server'
require 'mocha'

class TestXMLRPCServer < Test::Unit::TestCase
    def setup
        super
        assert_nothing_raised do
            @server = Puppet::Network::XMLRPCServer.new
        end
    end

    def test_initialize
        assert(@server.get_service_hook, "no service hook defined")

        assert_nothing_raised("Did not init @loadedhandlers") do
            assert(! @server.handler_loaded?(:puppetca),
                "server thinks handlers are loaded")
        end
    end
end

# $Id$

