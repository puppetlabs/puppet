#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-11-07.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/feature'

class TestFeatures < Test::Unit::TestCase
	include PuppetTest
	
	def setup
	    super
	    libdir = tempfile()
	    @features = Puppet::Feature.new(libdir)
    end
	
	def test_new
	    assert_nothing_raised do
	        @features.add(:failer) do
	            raise ArgumentError, "nopes"
            end
        end
        
        assert(@features.respond_to?(:failer?), "Feature method did not get added")
        assert_nothing_raised("failure propagated outside of feature") do
            assert(! @features.failer?, "failure was considered true")
        end
        
        # Now make one that succeeds
        $succeeds = nil
        assert_nothing_raised("Failed to add normal feature") do
            @features.add(:succeeds) do
                $succeeds = true
            end
        end
        assert($succeeds, "Block was not called on initialization")
        
        assert(@features.respond_to?(:succeeds?), "Did not add succeeding feature")
        assert_nothing_raised("Failed to call succeeds") { assert(@features.succeeds?, "Feature was not true") }
    end
    
    def test_libs
        assert_nothing_raised do
            @features.add(:puppet, :libs => %w{puppet})
        end
        
        assert(@features.puppet?)
        
        assert_nothing_raised do
            @features.add(:missing, :libs => %w{puppet no/such/library/okay})
        end
        
        assert(! @features.missing?, "Missing lib was considered true")
    end
end

# $Id$