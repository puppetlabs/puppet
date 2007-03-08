#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/client/ca'
require 'puppet/sslcertificates/support'

class TestClientCA < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def setup
        super
        @ca = Puppet::Network::Handler.ca.new
        @client = Puppet::Network::Client.ca.new :CA => @ca
    end

    def test_request_cert
        assert_nothing_raised("Could not request cert") do
            @client.request_cert
        end

        [:hostprivkey, :hostcert, :localcacert].each do |name|
            assert(FileTest.exists?(Puppet.config[name]),
                "Did not create cert %s" % name)
        end
    end

    # Make sure the ca defaults to specific ports and names
    def test_ca_server
        client = nil
        assert_nothing_raised do
            client = Puppet::Network::Client.ca.new
        end
    end
end

# $Id$
