#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-12-21.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestStateChange < Test::Unit::TestCase
	include PuppetTest
	class FakeState
	    attr_accessor :is, :should, :parent
	    def change_to_s
	        "fake change"
        end
	    def insync?
	        @is == @should
        end
        def log(msg)
            Puppet::Log.create(
                :level => :info,
                :source => self,
                :message => msg
            )
        end
        def noop
            false
        end
        def path
            "fakechange"
        end
        def sync
            if insync?
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
        state = FakeState.new
        state.is = :start
        state.should = :finish
        state.parent = :parent
        change = nil
        assert_nothing_raised do
            change = Puppet::StateChange.new(state)
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
	    
	    assert(coll.detect { |l| l.message == "fake change" }, "Did not log change")
	    assert_equal(change.state.is, change.state.should, "did not call sync method")
	    
	    # Now make sure that proxy sources can be set.
	    assert_nothing_raised do
    	    change.proxy = :other
	    end
	    # Reset, so we change again
	    change.state.is = :start
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
	    
	    assert(coll.detect { |l| l.message == "fake change" }, "Did not log change")
	    assert_equal(change.state.is, change.state.should, "did not call sync method")
    end
end

# $Id$