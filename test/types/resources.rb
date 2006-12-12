#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-12-12.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestResources < Test::Unit::TestCase
	include PuppetTest
	
	def add_purge_lister
        # Now define the list method
        class << @purgetype
            def list
                $purgemembers.values
            end
        end
    end
    
    def mk_purger(managed = false)
        @purgenum ||= 0
        @purgenum += 1
        obj = @purgetype.create :name => "purger%s" % @purgenum
        $purgemembers[obj[:name]] = obj
        if managed
            obj[:fake] = "testing"
        end
        obj
    end
	
	def mkpurgertype
        # Create a purgeable type
        $purgemembers = {}
        @purgetype = Puppet::Type.newtype(:purgetest) do
            newparam(:name, :namevar => true) {}
            newstate(:ensure) do
                newvalue(:absent) do
                    $purgemembers[@parent[:name]] = @parent
                end
                newvalue(:present) do
                    $purgemembers.delete(@parent[:name])
                end
            end
            newstate(:fake) do
                def sync
                    :faked
                end
            end
        end
        cleanup do
            Puppet::Type.rmtype(:purgetest)
        end
    end
	
	def setup
	    super
	    @type = Puppet::Type.type(:resources)
    end
	
	def test_initialize
	    assert(@type, "Could not retrieve resources type")
	    # Make sure we can't create them for types that don't exist
	    assert_raise(ArgumentError) do
	        @type.create :name => "thereisnotypewiththisname"
        end
        
        # Now make sure it works for a normal type
        usertype = nil
        assert_nothing_raised do
            usertype = @type.create :name => "user"
        end
        assert(usertype, "did not create user resource type")
        assert_equal(Puppet::Type.type(:user), usertype.resource_type,
            "resource_type was not set correctly")
    end
    
    def test_purge
        # Create a purgeable type
        mkpurgertype
        
        purger = nil
        assert_nothing_raised do
            purger = @type.create :name => "purgetest"
        end
        assert(purger, "did not get purger manager")
        
        # Make sure we throw an error, because the purger type does
        # not support listing.
        
        # It should work when we set it to false
        assert_nothing_raised do
            purger[:purge] = false
        end
        # but not true
        assert_raise(ArgumentError) do
            purger[:purge] = true
        end
        add_purge_lister()
        
        assert_equal($purgemembers.values.sort, @purgetype.list.sort)
        
        # and it should now succeed
        assert_nothing_raised do
            purger[:purge] = true
        end
        assert(purger.purge?, "purge boolean was not enabled")
        
        # Okay, now let's try doing some purging, yo
        managed = []
        unmanned = []
        3.times { managed << mk_purger(true) } # 3 managed
        3.times { unmanned << mk_purger(false) } # 3 unmanaged
        
        managed.each do |m|
            assert(m.managed?, "managed resource was not considered managed")
        end
        unmanned.each do |u|
            assert(! u.managed?, "unmanaged resource was considered managed")
        end

        # Now make sure the generate method only finds the unmanaged resources
        assert_equal(unmanned.collect { |r| r.title }.sort, purger.generate.collect { |r| r.title },
            "Did not return correct purge list")
    end
end

# $Id$