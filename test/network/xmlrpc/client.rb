#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/xmlrpc/client'
require 'mocha'

class TestXMLRPCClient < Test::Unit::TestCase
    include PuppetTest

    def setup
        Puppet::Util::SUIDManager.stubs(:asuser).yields
        super
    end

    def test_set_backtrace
        error = Puppet::Network::XMLRPCClientError.new("An error")
        assert_nothing_raised do
            error.set_backtrace ["caller"]
        end
        assert_equal(["caller"], error.backtrace)
    end

    # Make sure we correctly generate a netclient
    def test_handler_class
        # Create a test handler
        klass = Puppet::Network::XMLRPCClient
        yay = Class.new(Puppet::Network::Handler) do
            @interface = XMLRPC::Service::Interface.new("yay") { |iface|
                iface.add_method("array getcert(csr)")
            }

            @name = :Yay
        end
        Object.const_set("Yay", yay)

        net = nil
        assert_nothing_raised("Failed when retrieving client for handler") do
            net = klass.handler_class(yay)
        end

        assert(net, "did not get net client")
    end

    # Make sure the xmlrpc client is correctly reading all of the cert stuff
    # and setting it into the @http var
    def test_cert_setup
        client = nil
        assert_nothing_raised do
            client = Puppet::Network::XMLRPCClient.new()
        end

        ca = Puppet::Network::Handler.ca.new
        caclient = Puppet::Network::Client.ca.new :CA => ca
        caclient.request_cert

        class << client
            attr_accessor :http
        end

        client.http.expects(:ca_file=).with(Puppet[:localcacert])
        client.http.expects(:cert=).with(caclient.cert)
        client.http.expects(:key=).with(caclient.key)
        client.http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
        client.http.expects(:cert_store=)

        assert_nothing_raised do
            client.cert_setup(caclient)
        end
    end
end


