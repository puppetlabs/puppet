#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'puppettest/support/utils'
require 'puppet/network/xmlrpc/webrick_servlet'
require 'mocha'

class TestXMLRPCWEBrickServlet < Test::Unit::TestCase
  include PuppetTest
  def test_basics
    # Make sure we're doing things as our user info, rather than puppet/puppet
    setme
    set_mygroup
    Puppet[:user] = @me
    Puppet[:group] = @mygroup
    servlet = nil
    ca = Puppet::Network::Handler.ca.new

    assert_nothing_raised("Could not create servlet") do
      servlet = Puppet::Network::XMLRPC::WEBrickServlet.new([ca])
    end

    assert(servlet.get_service_hook, "service hook was not set up")


          assert(
        servlet.handler_loaded?(:puppetca),
        
      "Did not load handler")
  end
end


