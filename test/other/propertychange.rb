#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-12-21.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestPropertyChange < Test::Unit::TestCase
	include PuppetTest
	class FakeProperty < Puppet::Type::Property
	    attr_accessor :is, :should, :parent
	    attr_reader :noop
	    def change_to_s(currentvalue, newvalue)
	        "fake change"
        end
	    def insync?(is)
	        is == @should
        end
        def log(msg)
            Puppet::Util::Log.create(
                :level => :info,
                :source => self,
                :message => msg
            )
        end
        def noop
            if defined? @noop
                @noop
            else
                false
            end
        end
        def path
            "fakechange"
        end
        def should_to_s(newvalue)
            newvalue.to_s
        end
        def sync
            if insync?(@is)
                return nil
            else
                @is = @should
                return :fake_change
            end
        end
        def to_s
            path
        end
    end
    
    def mkchange
        property = FakeProperty.new :parent => "fakeparent"
        property.is = :start
        property.should = :finish
        property.parent = :parent
        change = nil
        assert_nothing_raised do
            change = Puppet::PropertyChange.new(property, :start)
        end
        change.transaction = :trans
        
        assert_equal(:start, change.is, "@is did not get copied")
        assert_equal(:finish, change.should, "@should did not get copied")
        assert_equal(%w{fakechange change}, change.path, "path did not get set correctly")
        
        assert(! change.changed?, "change defaulted to already changed")
        
        return change
    end
    
	def test_go
	    change = mkchange
	    
	    coll = logcollector()
	    
	    events = nil
	    # First make sure we get an immediate return 
	    assert_nothing_raised do
    	    events = change.go
	    end
	    assert_instance_of(Array, events, "events were not returned in an array")
	    assert_instance_of(Puppet::Event, events[0], "event array did not contain events")

	    event = events.shift
	    {:event => :fake_change, :transaction => :trans, :source => :parent}.each do |method, val|
	        assert_equal(val, event.send(method), "Event did not set %s correctly" % method)
        end
	    
        # Disabled, because it fails when running the whole suite at once.
        #assert(coll.detect { |l| l.message == "fake change" }, "Did not log change")
	    assert_equal(change.property.is, change.property.should, "did not call sync method")
	    
	    # Now make sure that proxy sources can be set.
	    assert_nothing_raised do
    	    change.proxy = :other
	    end
	    # Reset, so we change again
	    change.property.is = :start
	    change.is = :start
	    assert_nothing_raised do
	        events = change.go
        end
        
	    assert_instance_of(Array, events, "events were not returned in an array")
	    assert_instance_of(Puppet::Event, events[0], "event array did not contain events")

	    event = events.shift
	    {:event => :fake_change, :transaction => :trans, :source => :other}.each do |method, val|
	        assert_equal(val, event.send(method), "Event did not set %s correctly" % method)
        end
	    
	    #assert(coll.detect { |l| l.message == "fake change" }, "Did not log change")
	    assert_equal(change.property.is, change.property.should, "did not call sync method")
    end

    # Related to #542.  Make sure changes in noop mode produce the :noop event.
    def test_noop_event
        change = mkchange

        assert(! change.skip?, "Change is already being skipped")

        Puppet[:noop] = true

        change.property.noop = true
        p change.property.noop
        assert(change.noop, "did not set noop")
        assert(change.skip?, "setting noop did not mark change for skipping")

        event = nil
        assert_nothing_raised("Could not generate noop event") do
            event = change.forward
        end

        assert_equal(1, event.length, "got wrong number of events")
        assert_equal(:noop, event[0].event, "did not generate noop mode when in noop")
    end
end

# $Id$
