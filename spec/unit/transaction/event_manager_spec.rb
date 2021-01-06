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
    transaction = double('transaction')
    manager = Puppet::Transaction::EventManager.new(transaction)

    expect(transaction).to receive(:relationship_graph).and_return("mygraph")

    expect(manager.relationship_graph).to eq("mygraph")
  end

  describe "when queueing events" do
    before do
      @manager = Puppet::Transaction::EventManager.new(@transaction)

      @resource = Puppet::Type.type(:file).new :path => make_absolute("/my/file")

      @graph = double('graph', :matching_edges => [], :resource => @resource)
      allow(@manager).to receive(:relationship_graph).and_return(@graph)

      @event = Puppet::Transaction::Event.new(:name => :foo, :resource => @resource)
    end

    it "should store all of the events in its event list" do
      @event2 = Puppet::Transaction::Event.new(:name => :bar, :resource => @resource)
      @manager.queue_events(@resource, [@event, @event2])

      expect(@manager.events).to include(@event)
      expect(@manager.events).to include(@event2)
    end

    it "should queue events for the target and callback of any matching edges" do
      edge1 = double("edge1", :callback => :c1, :source => double("s1"), :target => double("t1", :c1 => nil))
      edge2 = double("edge2", :callback => :c2, :source => double("s2"), :target => double("t2", :c2 => nil))

      expect(@graph).to receive(:matching_edges).with(@event, anything).and_return([edge1, edge2])

      expect(@manager).to receive(:queue_events_for_resource).with(@resource, edge1.target, edge1.callback, [@event])
      expect(@manager).to receive(:queue_events_for_resource).with(@resource, edge2.target, edge2.callback, [@event])

      @manager.queue_events(@resource, [@event])
    end

    it "should queue events for the changed resource if the resource is self-refreshing and not being deleted" do
      allow(@graph).to receive(:matching_edges).and_return([])

      expect(@resource).to receive(:self_refresh?).and_return(true)
      expect(@resource).to receive(:deleting?).and_return(false)
      expect(@manager).to receive(:queue_events_for_resource).with(@resource, @resource, :refresh, [@event])

      @manager.queue_events(@resource, [@event])
    end

    it "should not queue events for the changed resource if the resource is not self-refreshing" do
      allow(@graph).to receive(:matching_edges).and_return([])

      expect(@resource).to receive(:self_refresh?).and_return(false)
      allow(@resource).to receive(:deleting?).and_return(false)
      expect(@manager).not_to receive(:queue_events_for_resource)

      @manager.queue_events(@resource, [@event])
    end

    it "should not queue events for the changed resource if the resource is being deleted" do
      allow(@graph).to receive(:matching_edges).and_return([])

      expect(@resource).to receive(:self_refresh?).and_return(true)
      expect(@resource).to receive(:deleting?).and_return(true)
      expect(@manager).not_to receive(:queue_events_for_resource)

      @manager.queue_events(@resource, [@event])
    end

    it "should ignore edges that don't have a callback" do
      edge1 = double("edge1", :callback => :nil, :source => double("s1"), :target => double("t1", :c1 => nil))

      expect(@graph).to receive(:matching_edges).and_return([edge1])

      expect(@manager).not_to receive(:queue_events_for_resource)

      @manager.queue_events(@resource, [@event])
    end

    it "should ignore targets that don't respond to the callback" do
      edge1 = double("edge1", :callback => :c1, :source => double("s1"), :target => double("t1"))

      expect(@graph).to receive(:matching_edges).and_return([edge1])

      expect(@manager).not_to receive(:queue_events_for_resource)

      @manager.queue_events(@resource, [@event])
    end

    it "should dequeue events for the changed resource if an event with invalidate_refreshes is processed" do
      @event2 = Puppet::Transaction::Event.new(:name => :foo, :resource => @resource, :invalidate_refreshes => true)

      allow(@graph).to receive(:matching_edges).and_return([])

      expect(@manager).to receive(:dequeue_events_for_resource).with(@resource, :refresh)

      @manager.queue_events(@resource, [@event, @event2])
    end
  end

  describe "when queueing events for a resource" do
    before do
      @transaction = double('transaction')
      @manager = Puppet::Transaction::EventManager.new(@transaction)
    end

    it "should do nothing if no events are queued" do
      @manager.queued_events(double("target")) { |callback, events| raise "should never reach this" }
    end

    it "should yield the callback and events for each callback" do
      target = double("target")

      2.times do |i|
        @manager.queue_events_for_resource(double("source", :info => nil), target, "callback#{i}", ["event#{i}"])
      end

      @manager.queued_events(target) { |callback, events| }
    end

    it "should use the source to log that it's scheduling a refresh of the target" do
      target = double("target")
      source = double('source')
      expect(source).to receive(:info)

      @manager.queue_events_for_resource(source, target, "callback", ["event"])

      @manager.queued_events(target) { |callback, events| }
    end
  end

  describe "when processing events for a given resource" do
    before do
      @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil)
      @manager = Puppet::Transaction::EventManager.new(@transaction)
      allow(@manager).to receive(:queue_events)

      @resource = Puppet::Type.type(:file).new :path => make_absolute("/my/file")
      @event = Puppet::Transaction::Event.new(:name => :event, :resource => @resource)

      @resource.class.send(:define_method, :callback1) {}
      @resource.class.send(:define_method, :callback2) {}
    end

    it "should call the required callback once for each set of associated events" do
      expect(@manager).to receive(:queued_events).with(@resource).and_yield(:callback1, [@event]).and_yield(:callback2, [@event])

      expect(@resource).to receive(:callback1)
      expect(@resource).to receive(:callback2)

      @manager.process_events(@resource)
    end

    it "should set the 'restarted' state on the resource status" do
      expect(@manager).to receive(:queued_events).with(@resource).and_yield(:callback1, [@event])

      allow(@resource).to receive(:callback1)

      @manager.process_events(@resource)

      expect(@transaction.resource_status(@resource)).to be_restarted
    end

    it "should have an event on the resource status" do
      expect(@manager).to receive(:queued_events).with(@resource).and_yield(:callback1, [@event])

      allow(@resource).to receive(:callback1)

      @manager.process_events(@resource)

      expect(@transaction.resource_status(@resource).events.length).to eq(1)
    end

    it "should queue a 'restarted' event generated by the resource" do
      expect(@manager).to receive(:queued_events).with(@resource).and_yield(:callback1, [@event])

      allow(@resource).to receive(:callback1)

      expect(@resource).to receive(:event).with(:message => "Triggered 'callback1' from 1 event", :status => 'success', :name => 'callback1')
      expect(@resource).to receive(:event).with(:name => :restarted, :status => "success").and_return("myevent")
      expect(@manager).to receive(:queue_events).with(@resource, ["myevent"])

      @manager.process_events(@resource)
    end

    it "should log that it restarted" do
      expect(@manager).to receive(:queued_events).with(@resource).and_yield(:callback1, [@event])

      allow(@resource).to receive(:callback1)

      expect(@resource).to receive(:notice).with(/Triggered 'callback1'/)

      @manager.process_events(@resource)
    end

    describe "and the events include a noop event and at least one non-noop event" do
      before do
        allow(@event).to receive(:status).and_return("noop")
        @event2 = Puppet::Transaction::Event.new(:name => :event, :resource => @resource)
        @event2.status = "success"
        expect(@manager).to receive(:queued_events).with(@resource).and_yield(:callback1, [@event, @event2])
        @resource.class.send(:define_method, :callback1) {}
      end

      it "should call the callback" do

        expect(@resource).to receive(:callback1)

        @manager.process_events(@resource)
      end
    end

    describe "and the events are all noop events" do
      before do
        allow(@event).to receive(:status).and_return("noop")
        allow(@resource).to receive(:event).and_return(Puppet::Transaction::Event.new)
        expect(@manager).to receive(:queued_events).with(@resource).and_yield(:callback1, [@event])
        @resource.class.send(:define_method, :callback1) {}
      end

      it "should log" do
        expect(@resource).to receive(:notice).with(/Would have triggered 'callback1'/)

        @manager.process_events(@resource)
      end

      it "should not call the callback" do
        expect(@resource).not_to receive(:callback1)

        @manager.process_events(@resource)
      end

      it "should queue a new noop event generated from the resource" do
        event = Puppet::Transaction::Event.new
        expect(@resource).to receive(:event).with(:status => "noop", :name => :noop_restart).and_return(event)
        expect(@manager).to receive(:queue_events).with(@resource, [event])

        @manager.process_events(@resource)
      end
    end

    describe "and the resource has noop set to true" do
      before do
        allow(@event).to receive(:status).and_return("success")
        allow(@resource).to receive(:event).and_return(Puppet::Transaction::Event.new)
        allow(@resource).to receive(:noop?).and_return(true)
        expect(@manager).to receive(:queued_events).with(@resource).and_yield(:callback1, [@event])
        @resource.class.send(:define_method, :callback1) {}
      end

      it "should log" do
        expect(@resource).to receive(:notice).with(/Would have triggered 'callback1'/)

        @manager.process_events(@resource)
      end

      it "should not call the callback" do
        expect(@resource).not_to receive(:callback1)

        @manager.process_events(@resource)
      end

      it "should queue a new noop event generated from the resource" do
        event = Puppet::Transaction::Event.new
        expect(@resource).to receive(:event).with(:status => "noop", :name => :noop_restart).and_return(event)
        expect(@manager).to receive(:queue_events).with(@resource, [event])

        @manager.process_events(@resource)
      end
    end

    describe "and the callback fails" do
      before do
        @resource.class.send(:define_method, :callback1) { raise "a failure" }

        expect(@manager).to receive(:queued_events).and_yield(:callback1, [@event])
      end

      it "should emit an error and log but not fail" do
        expect(@resource).to receive(:err).with('Failed to call callback1: a failure').and_call_original

        @manager.process_events(@resource)

        expect(@logs).to include(an_object_having_attributes(level: :err, message: 'a failure'))
      end

      it "should set the 'failed_restarts' state on the resource status" do
        @manager.process_events(@resource)
        expect(@transaction.resource_status(@resource)).to be_failed_to_restart
      end

      it "should set the 'failed' state on the resource status" do
        @manager.process_events(@resource)
        expect(@transaction.resource_status(@resource)).to be_failed
      end

      it "should record a failed event on the resource status" do
        @manager.process_events(@resource)

        expect(@transaction.resource_status(@resource).events.length).to eq(1)
        expect(@transaction.resource_status(@resource).events[0].status).to eq('failure')
      end

      it "should not queue a 'restarted' event" do
        expect(@manager).not_to receive(:queue_events)
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
      @catalog = Puppet::Resource::Catalog.new
      @target = Puppet::Type.type(:exec).new(name: 'target', path: ENV['PATH'])
      @resource = Puppet::Type.type(:exec).new(name: 'resource', path: ENV['PATH'], notify: @target)
      @catalog.add_resource(@resource, @target)

      @manager = Puppet::Transaction::EventManager.new(Puppet::Transaction.new(@catalog, nil, nil))

      @event  = Puppet::Transaction::Event.new(:name => :notify, :resource => @target)
      @event2 = Puppet::Transaction::Event.new(:name => :service_start, :resource => @target, :invalidate_refreshes => true)
    end

    it "should succeed when there's no invalidated event" do
      @manager.queue_events(@target, [@event2])
    end

    describe "and the events were dequeued/invalidated" do
      before do
        expect(@resource).to receive(:info).with(/Scheduling refresh/)
        expect(@target).to receive(:info).with(/Unscheduling/)
      end

      it "should not run an event or log" do
        expect(@target).not_to receive(:notice).with(/Would have triggered 'refresh'/)
        expect(@target).not_to receive(:refresh)

        @manager.queue_events(@resource, [@event])
        @manager.queue_events(@target, [@event2])
        @manager.process_events(@resource)
        @manager.process_events(@target)
      end
    end
  end
end
