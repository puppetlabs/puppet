#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/client'

class TestClient < Test::Unit::TestCase
    def test_set_backtrace
        error = Puppet::Network::NetworkClientError.new("An error")
        assert_nothing_raised do
            error.set_backtrace ["caller"]
        end
    end
end

# $Id$

