#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/transaction/event_manager'

describe Puppet::Transaction::EventManager do
  include PuppetSpec::Files

  describe "at initialization" do
    it "should require a transaction" do
      expect(Puppet::Transaction::EventManager.new("trans").transaction).to eq("trans")
    end
  end

  it "should delegate its relationship graph to the transaction" do
    transaction = stub 'transaction'
    manager = Puppet::Transaction::EventManager.new(transaction)

    transaction.expects(:relationship_graph).returns "mygraph"

    expect(manager.relationship_graph).to eq("mygraph")
  end

  describe "when queueing events" do
    before do
      @manager = Puppet::Transaction::EventManager.new(@transaction)

      @resource = Puppet::Type.type(:file).new :path => make_absolute("/my/file")

      @graph = stub 'graph', :matching_edges => [], :resource => @resource
      @manager.stubs(:relationship_graph).returns @graph

      @event = Puppet::Transaction::Event.new(:name => :foo, :resource => @resource)
    end

    it "should store all of the events in its event list" do
      @event2 = Puppet::Transaction::Event.new(:name => :bar, :resource => @resource)
      @manager.queue_events(@resource, [@event, @event2])

      expect(@manager.events).to include(@event)
      expect(@manager.events).to include(@event2)
    end

    it "should queue events for the target and callback of any matching edges" do
      edge1 = stub("edge1", :callback => :c1, :source => stub("s1"), :target => stub("t1", :c1 => nil))
      edge2 = stub("edge2", :callback => :c2, :source => stub("s2"), :target => stub("t2", :c2 => nil))

      @graph.expects(:matching_edges).with { |event, resource| event == @event }.returns [edge1, edge2]

      @manager.expects(:queue_events_for_resource).with(@resource, edge1.target, edge1.callback, [@event])
      @manager.expects(:queue_events_for_resource).with(@resource, edge2.target, edge2.callback, [@event])

      @manager.queue_events(@resource, [@event])
    end

    it "should queue events for the changed resource if the resource is self-refreshing and not being deleted" do
      @graph.stubs(:matching_edges).returns []

      @resource.expects(:self_refresh?).returns true
      @resource.expects(:deleting?).returns false
      @manager.expects(:queue_events_for_resource).with(@resource, @resource, :refresh, [@event])

      @manager.queue_events(@resource, [@event])
    end

    it "should not queue events for the changed resource if the resource is not self-refreshing" do
      @graph.stubs(:matching_edges).returns []

      @resource.expects(:self_refresh?).returns false
      @resource.stubs(:deleting?).returns false
      @manager.expects(:queue_events_for_resource).never

      @manager.queue_events(@resource, [@event])
    end

    it "should not queue events for the changed resource if the resource is being deleted" do
      @graph.stubs(:matching_edges).returns []

      @resource.expects(:self_refresh?).returns true
      @resource.expects(:deleting?).returns true
      @manager.expects(:queue_events_for_resource).never

      @manager.queue_events(@resource, [@event])
    end

    it "should ignore edges that don't have a callback" do
      edge1 = stub("edge1", :callback => :nil, :source => stub("s1"), :target => stub("t1", :c1 => nil))

      @graph.expects(:matching_edges).returns [edge1]

      @manager.expects(:queue_events_for_resource).never

      @manager.queue_events(@resource, [@event])
    end

    it "should ignore targets that don't respond to the callback" do
      edge1 = stub("edge1", :callback => :c1, :source => stub("s1"), :target => stub("t1"))

      @graph.expects(:matching_edges).returns [edge1]

      @manager.expects(:queue_events_for_resource).never

      @manager.queue_events(@resource, [@event])
    end

    it "should dequeue events for the changed resource if an event with invalidate_refreshes is processed" do
      @event2 = Puppet::Transaction::Event.new(:name => :foo, :resource => @resource, :invalidate_refreshes => true)

      @graph.stubs(:matching_edges).returns []

      @manager.expects(:dequeue_events_for_resource).with(@resource, :refresh)

      @manager.queue_events(@resource, [@event, @event2])
    end
  end

  describe "when queueing events for a resource" do
    before do
      @transaction = stub 'transaction'
      @manager = Puppet::Transaction::EventManager.new(@transaction)
    end

    it "should do nothing if no events are queued" do
      @manager.queued_events(stub("target")) { |callback, events| raise "should never reach this" }
    end

    it "should yield the callback and events for each callback" do
      target = stub("target")

      2.times do |i|
        @manager.queue_events_for_resource(stub("source", :info => nil), target, "callback#{i}", ["event#{i}"])
      end

      @manager.queued_events(target) { |callback, events| }
    end

    it "should use the source to log that it's scheduling a refresh of the target" do
      target = stub("target")
      source = stub 'source'
      source.expects(:info)

      @manager.queue_events_for_resource(source, target, "callback", ["event"])

      @manager.queued_events(target) { |callback, events| }
    end
  end

  describe "when processing events for a given resource" do
    before do
      @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil)
      @manager = Puppet::Transaction::EventManager.new(@transaction)
      @manager.stubs(:queue_events)

      @resource = Puppet::Type.type(:file).new :path => make_absolute("/my/file")
      @event = Puppet::Transaction::Event.new(:name => :event, :resource => @resource)
    end

    it "should call the required callback once for each set of associated events" do
      @manager.expects(:queued_events).with(@resource).multiple_yields([:callback1, [@event]], [:callback2, [@event]])

      @resource.expects(:callback1)
      @resource.expects(:callback2)

      @manager.process_events(@resource)
    end

    it "should set the 'restarted' state on the resource status" do
      @manager.expects(:queued_events).with(@resource).yields(:callback1, [@event])

      @resource.stubs(:callback1)

      @manager.process_events(@resource)

      expect(@transaction.resource_status(@resource)).to be_restarted
    end

    it "should queue a 'restarted' event generated by the resource" do
      @manager.expects(:queued_events).with(@resource).yields(:callback1, [@event])

      @resource.stubs(:callback1)

      @resource.expects(:event).with(:name => :restarted, :status => "success").returns "myevent"
      @manager.expects(:queue_events).with(@resource, ["myevent"])

      @manager.process_events(@resource)
    end

    it "should log that it restarted" do
      @manager.expects(:queued_events).with(@resource).yields(:callback1, [@event])

      @resource.stubs(:callback1)

      @resource.expects(:notice).with { |msg| msg.include?("Triggered 'callback1'") }

      @manager.process_events(@resource)
    end

    describe "and the events include a noop event and at least one non-noop event" do
      before do
        @event.stubs(:status).returns "noop"
        @event2 = Puppet::Transaction::Event.new(:name => :event, :resource => @resource)
        @event2.status = "success"
        @manager.expects(:queued_events).with(@resource).yields(:callback1, [@event, @event2])
      end

      it "should call the callback" do
        @resource.expects(:callback1)

        @manager.process_events(@resource)
      end
    end

    describe "and the events are all noop events" do
      before do
        @event.stubs(:status).returns "noop"
        @resource.stubs(:event).returns(Puppet::Transaction::Event.new)
        @manager.expects(:queued_events).with(@resource).yields(:callback1, [@event])
      end

      it "should log" do
        @resource.expects(:notice).with { |msg| msg.include?("Would have triggered 'callback1'") }

        @manager.process_events(@resource)
      end

      it "should not call the callback" do
        @resource.expects(:callback1).never

        @manager.process_events(@resource)
      end

      it "should queue a new noop event generated from the resource" do
        event = Puppet::Transaction::Event.new
        @resource.expects(:event).with(:status => "noop", :name => :noop_restart).returns event
        @manager.expects(:queue_events).with(@resource, [event])

        @manager.process_events(@resource)
      end
    end

    describe "and the resource has noop set to true" do
      before do
        @event.stubs(:status).returns "success"
        @resource.stubs(:event).returns(Puppet::Transaction::Event.new)
        @resource.stubs(:noop?).returns(true)
        @manager.expects(:queued_events).with(@resource).yields(:callback1, [@event])
      end

      it "should log" do
        @resource.expects(:notice).with { |msg| msg.include?("Would have triggered 'callback1'") }

        @manager.process_events(@resource)
      end

      it "should not call the callback" do
        @resource.expects(:callback1).never

        @manager.process_events(@resource)
      end

      it "should queue a new noop event generated from the resource" do
        event = Puppet::Transaction::Event.new
        @resource.expects(:event).with(:status => "noop", :name => :noop_restart).returns event
        @manager.expects(:queue_events).with(@resource, [event])

        @manager.process_events(@resource)
      end
    end


    describe "and the callback fails" do
      before do
        @resource.expects(:callback1).raises "a failure"
        @resource.stubs(:err)

        @manager.expects(:queued_events).yields(:callback1, [@event])
      end

      it "should log but not fail" do
        @resource.expects(:err)

        expect { @manager.process_events(@resource) }.not_to raise_error
      end

      it "should set the 'failed_restarts' state on the resource status" do
        @manager.process_events(@resource)
        expect(@transaction.resource_status(@resource)).to be_failed_to_restart
      end

      it "should not queue a 'restarted' event" do
        @manager.expects(:queue_events).never
        @manager.process_events(@resource)
      end

      it "should set the 'restarted' state on the resource status" do
        @manager.process_events(@resource)
        expect(@transaction.resource_status(@resource)).not_to be_restarted
      end
    end
  end

  describe "when queueing then processing events for a given resource" do
    before do
      @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil)
      @manager = Puppet::Transaction::EventManager.new(@transaction)

      @resource = Puppet::Type.type(:file).new :path => make_absolute("/my/file")
      @target = Puppet::Type.type(:file).new :path => make_absolute("/your/file")

      @graph = stub 'graph'
      @graph.stubs(:matching_edges).returns []
      @graph.stubs(:matching_edges).with(anything, @resource).returns [stub('edge', :target => @target, :callback => :refresh)]
      @manager.stubs(:relationship_graph).returns @graph

      @event  = Puppet::Transaction::Event.new(:name => :notify, :resource => @target)
      @event2 = Puppet::Transaction::Event.new(:name => :service_start, :resource => @target, :invalidate_refreshes => true)
    end

    it "should succeed when there's no invalidated event" do
      @manager.queue_events(@target, [@event2])
    end

    describe "and the events were dequeued/invalidated" do
      before do
        @resource.expects(:info).with { |msg| msg.include?("Scheduling refresh") }
        @target.expects(:info).with { |msg| msg.include?("Unscheduling") }
      end

      it "should not run an event or log" do
        @target.expects(:notice).with { |msg| msg.include?("Would have triggered 'refresh'") }.never
        @target.expects(:refresh).never

        @manager.queue_events(@resource, [@event])
        @manager.queue_events(@target, [@event2])
        @manager.process_events(@resource)
        @manager.process_events(@target)
      end
    end
  end
end
