#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

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

        caclient = mock 'client', :cert => :ccert, :key => :ckey

        FileTest.expects(:exist?).with(Puppet[:localcacert]).returns(true)

        store = mock 'sslstore'
        OpenSSL::X509::Store.expects(:new).returns(store)
        store.expects(:add_file).with(Puppet[:localcacert])
        store.expects(:purpose=).with(OpenSSL::X509::PURPOSE_SSL_CLIENT)

        class << client
            attr_accessor :http
        end

        http = mock 'http'
        client.http = http

        http.expects(:ca_file).returns(false)
        http.expects(:ca_file=).with(Puppet[:localcacert])
        http.expects(:cert=).with(:ccert)
        http.expects(:key=).with(:ckey)
        http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
        http.expects(:enable_post_connection_check=).with(Puppet[:http_enable_post_connection_check])
        http.expects(:cert_store=)

        assert_nothing_raised do
            client.cert_setup(caclient)
        end
    end

    def test_http_cache
    end
end
