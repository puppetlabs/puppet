#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppettest'
require 'puppet/network/rights'

class TestRights < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    @store = Puppet::Network::Rights.new
  end


  def test_rights
    assert_raise(ArgumentError, "Did not fail on unknown right") {
      @store.allowed?(:write, "host.madstop.com", "0.0.0.0")
    }

    assert_nothing_raised {
      @store.newright(:write)
    }


          assert(
        ! @store.allowed?(:write, "host.madstop.com", "0.0.0.0"),
        
      "Defaulted to allowing access")

    assert_nothing_raised {
      @store[:write].info "This is a log message"
    }

    assert_logged(:info, /This is a log message/, "did not log from Rights")
  end
end


