#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-01-28.
#  Copyright (c) 2007. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestBaseServiceProvider < Test::Unit::TestCase
	include PuppetTest

	def test_base
	    running = tempfile()
	    
	    commands = {}
	    %w{touch rm test}.each do |c|
    	    path = %x{which #{c}}.chomp
    	    if path == ""
    	        $stderr.puts "Cannot find '#{c}'; cannot test base service provider"
    	        return
            end
            commands[c.to_sym] = path
        end
	    service = Puppet::Type.type(:service).create(
	        :name => "yaytest", :provider => :base,
	        :start => "%s %s" % [commands[:touch], running],
	        :status => "%s -f %s" % [commands[:test], running],
	        :stop => "%s %s" % [commands[:rm], running]
	    )
	    
	    provider = service.provider
	    assert(provider, "did not get base provider")
	    
	    assert_nothing_raised do
	        provider.start
        end
        assert(FileTest.exists?(running), "start was not called correctly")
        assert_nothing_raised do
            assert_equal(:running, provider.status, "status was not returned correctly")
        end
        assert_nothing_raised do
            provider.stop
        end
        assert(! FileTest.exists?(running), "stop was not called correctly")
        assert_nothing_raised do
            assert_equal(:stopped, provider.status, "status was not returned correctly")
        end
    end
end

# $Id$