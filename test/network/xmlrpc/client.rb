#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

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
end
