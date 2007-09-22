#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'mocha'
require 'puppettest'
require 'puppet/network/client/ca'
require 'puppet/sslcertificates/support'

class TestClientCA < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def setup
        Puppet::Util::SUIDManager.stubs(:asuser).yields
        super
        @ca = Puppet::Network::Handler.ca.new
        @client = Puppet::Network::Client.ca.new :CA => @ca
    end

    def test_request_cert
        assert_nothing_raised("Could not request cert") do
            @client.request_cert
        end

        [:hostprivkey, :hostcert, :localcacert].each do |name|
            assert(FileTest.exists?(Puppet.settings[name]),
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

    # #578
    def test_invalid_certs_are_not_written
        # Run the get once, which should be valid

        assert_nothing_raised("Could not get a certificate") do
            @client.request_cert
        end

        # Now remove the cert and keys, so we get a broken cert
        File.unlink(Puppet[:hostcert])
        File.unlink(Puppet[:localcacert])
        File.unlink(Puppet[:hostprivkey])

        @client = Puppet::Network::Client.ca.new :CA => @ca
        @ca.expects(:getcert).returns("yay") # not a valid cert
        # Now make sure it fails, since we'll get the old cert but have new keys
        assert_raise(Puppet::Network::Client::CA::InvalidCertificate, "Did not fail on invalid cert") do
            @client.request_cert
        end

        # And then make sure the cert isn't written to disk
        assert(! FileTest.exists?(Puppet[:hostcert]),
            "Invalid cert got written to disk")
    end
end

# $Id$
