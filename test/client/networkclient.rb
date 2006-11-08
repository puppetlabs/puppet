#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/client'
require 'puppet/server'
require 'puppettest'

class TestClient < Test::Unit::TestCase
    def test_set_backtrace
        error = Puppet::NetworkClientError.new("An error")
        assert_nothing_raised do
            error.set_backtrace ["caller"]
        end
    end
end

# $Id$

