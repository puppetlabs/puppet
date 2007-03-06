#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/xmlrpc/webrick_servlet'
require 'mocha'

class TestXMLRPCWEBrickServlet < Test::Unit::TestCase
    def test_basics
        servlet = nil
        ca = Puppet::Network::Handler.ca.new

        assert_nothing_raised("Could not create servlet") do
            servlet = Puppet::Network::XMLRPC::WEBrickServlet.new([ca])
        end

        assert(servlet.get_service_hook, "service hook was not set up")

        assert(servlet.handler_loaded?(:puppetca),
            "Did not load handler")
    end
end

# $Id$

