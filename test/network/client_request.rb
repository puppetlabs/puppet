#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'

require 'puppet/network/client_request'

class TestClientRequest < Test::Unit::TestCase
  include PuppetTest

  def test_initialize
    req = nil
    assert_nothing_raised do
      req = Puppet::Network::ClientRequest.new("name", "ip", false)
    end

    assert_equal("name", req.name, "host name was not set correctly")
    assert_equal("ip", req.ip, "host ip was not set correctly")
    assert_equal(false, req.authenticated, "host auth was not set correctly")
    assert(! req.authenticated, "host was incorrectly considered authenticated")

    req.authenticated = true
    assert(req.authenticated, "host was not considered authenticated")

    assert_raise(ArgumentError) do
      req.call
    end

    req.handler = "yay"
    req.method = "foo"
    assert_equal("yay.foo", req.call, "call was not built correctly")

    assert_equal("name(ip)", req.to_s, "request string not correct")
  end
end


