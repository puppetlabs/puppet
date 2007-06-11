#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/server/mongrel'

class TestMongrelServer < PuppetTest::TestCase
    confine "Missing mongrel" => Puppet.features.mongrel?

    include PuppetTest::ServerTest

    def mkserver(handlers = nil)
        handlers ||= { :Status => nil }
        mongrel = Puppet::Network::Server::Mongrel.new(handlers)
    end

    # Make sure client info is correctly extracted.
    def test_client_info
        obj = Object.new
        obj.metaclass.send(:attr_accessor, :params)
        params = {}
        obj.params = params

        mongrel = mkserver

        ip = Facter.value(:ipaddress)
        params["REMOTE_ADDR"] = ip
        params[Puppet[:ssl_client_header]] = "/CN=host.domain.com"

        info = nil
        assert_nothing_raised("Could not call client_info") do
            info = mongrel.send(:client_info, obj)
        end

        assert(info.authenticated?, "Client info object was not marked valid even though the header was present")
        assert_equal(ip, info.ip, "Did not copy over ip correctly")
        assert_equal("host.domain.com", info.name, "Did not copy over hostname correctly")

        # Now try it with a different header name
        params.delete(Puppet[:ssl_client_header])
        Puppet[:ssl_client_header] = "header_testing"
        params["header_testing"] = "/CN=other.domain.com"
        info = nil
        assert_nothing_raised("Could not call client_info with other header") do
            info = mongrel.send(:client_info, obj)
        end

        assert(info.authenticated?, "Client info object was not marked valid even though the header was present")
        assert_equal(ip, info.ip, "Did not copy over ip correctly")
        assert_equal("other.domain.com", info.name, "Did not copy over hostname correctly")

        # Now make sure it's considered invalid without that header
        params.delete("header_testing")
        info = nil
        assert_nothing_raised("Could not call client_info with no header") do
            info = mongrel.send(:client_info, obj)
        end

        assert(! info.authenticated?, "Client info object was marked valid without header")
        assert_equal(ip, info.ip, "Did not copy over ip correctly")
        assert_equal(Resolv.getname(ip), info.name, "Did not look up hostname correctly")
    end
end

# $Id$
