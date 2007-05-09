#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'

class TestServiceType < Test::Unit::TestCase
	include PuppetTest

    # #199
    def test_no_refresh_when_starting
        service = Puppet::Type.type(:service).create :name => "testing",
            :ensure => :running, :provider => :base

        # First make sure it does not refresh
        service.provider.expects(:restart).never

        assert_nothing_raised do
            service.refresh
        end
    end

    def test_refresh_normally
        service = Puppet::Type.type(:service).create :name => "testing",
            :ensure => :running, :provider => :base, :status => "cat /dev/null"

        service.provider.expects(:restart)

        assert_nothing_raised do
            service.refresh
        end
    end
end

# $Id$
