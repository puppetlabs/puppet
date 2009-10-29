#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/transaction'

describe Puppet::Transaction do
    describe "when evaluating a resource" do
        before do
            @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
            @transaction.stubs(:eval_children_and_apply_resource)
            @transaction.stubs(:skip?).returns false

            @resource = stub("resource")
        end

        it "should check whether the resource should be skipped" do
            @transaction.expects(:skip?).with(@resource).returns false

            @transaction.eval_resource(@resource)
        end

        it "should eval and apply children" do
            @transaction.expects(:eval_children_and_apply_resource).with(@resource)

            @transaction.eval_resource(@resource)
        end

        it "should process events" do
            @transaction.expects(:process_events).with(@resource)

            @transaction.eval_resource(@resource)
        end

        describe "and the resource should be skipped" do
            before do
                @transaction.expects(:skip?).with(@resource).returns true
            end

            it "should increment the 'skipped' count" do
                @transaction.eval_resource(@resource)
                @transaction.resourcemetrics[:skipped].should == 1
            end
        end
    end

    describe "when applying changes" do
        before do
            @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
            @transaction.stubs(:queue_events)

            @resource = stub 'resource'
            @property = stub 'property', :is_to_s => "is", :should_to_s => "should"
            @change = stub 'change', :property => @property, :changed= => nil, :forward => nil, :is => "is", :should => "should"
        end

        it "should apply each change" do
            c1 = stub 'c1', :property => @property, :changed= => nil
            c1.expects(:forward)
            c2 = stub 'c2', :property => @property, :changed= => nil
            c2.expects(:forward)

            @transaction.apply_changes(@resource, [c1, c2])
        end

        it "should queue the events from each change" do
            c1 = stub 'c1', :forward => "e1", :property => @property, :changed= => nil
            c2 = stub 'c2', :forward => "e2", :property => @property, :changed= => nil

            @transaction.expects(:queue_events).with(["e1"])
            @transaction.expects(:queue_events).with(["e2"])

            @transaction.apply_changes(@resource, [c1, c2])
        end

        it "should mark the change as 'changed'" do
            @change.expects(:changed=).with true
            @transaction.apply_changes(@resource, [@change])
        end

        it "should store the change in the transaction's change list" do
            @transaction.apply_changes(@resource, [@change])
            @transaction.changes.should include(@change)
        end

        it "should increment the number of applied resources" do
            @transaction.apply_changes(@resource, [@change])
            @transaction.resourcemetrics[:applied].should == 1
        end

        describe "and a change fails" do
            before do
                @change.expects(:forward).raises "a failure"
                @change.property.stubs(:err)
            end

            it "should rescue the exception" do
                lambda { @transaction.apply_changes(@resource, [@change]) }.should_not raise_error
            end

            it "should log the failure with the change's property" do
                @change.property.expects(:err)
                @transaction.apply_changes(@resource, [@change])
            end

            it "should increment the failures" do
                @transaction.apply_changes(@resource, [@change])
                @transaction.should be_any_failed
            end
        end
    end

    describe "when queueing events" do
        before do
            @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)

            @graph = stub 'graph', :matching_edges => []
            @transaction.stubs(:relationship_graph).returns @graph

            @resource = stub("resource", :self_refresh? => false, :deleting => false)
            @event = Puppet::Transaction::Event.new(:foo, @resource)
        end

        it "should store each event in its event list" do
            @transaction.queue_events(@event)

            @transaction.events.should include(@event)
        end

        it "should use the resource from the first edge as the source of all of the events" do
            event1 = Puppet::Transaction::Event.new(:foo, @resource)
            event2 = Puppet::Transaction::Event.new(:foo, stub('resource2', :self_refresh? => false, :deleting? => false))

            @graph.expects(:matching_edges).with { |events, resource| resource == event1.resource }.returns []

            @transaction.queue_events(event1, event2)
        end

        it "should queue events for the target and callback of any matching edges" do
            edge1 = stub("edge1", :callback => :c1, :source => stub("s1"), :target => stub("t1", :c1 => nil))
            edge2 = stub("edge2", :callback => :c2, :source => stub("s2"), :target => stub("t2", :c2 => nil))

            @graph.expects(:matching_edges).with { |events, resource| events == [@event] }.returns [edge1, edge2]

            @transaction.expects(:queue_events_for_resource).with(@resource, edge1.target, edge1.callback, [@event])
            @transaction.expects(:queue_events_for_resource).with(@resource, edge2.target, edge2.callback, [@event])

            @transaction.queue_events(@event)
        end

        it "should queue events for the changed resource if the resource is self-refreshing and not being deleted" do
            @graph.stubs(:matching_edges).returns []

            @resource.expects(:self_refresh?).returns true
            @resource.expects(:deleting?).returns false
            @transaction.expects(:queue_events_for_resource).with(@resource, @resource, :refresh, [@event])

            @transaction.queue_events(@event)
        end

        it "should not queue events for the changed resource if the resource is not self-refreshing" do
            @graph.stubs(:matching_edges).returns []

            @resource.expects(:self_refresh?).returns false
            @resource.stubs(:deleting?).returns false
            @transaction.expects(:queue_events_for_resource).never

            @transaction.queue_events(@event)
        end

        it "should not queue events for the changed resource if the resource is being deleted" do
            @graph.stubs(:matching_edges).returns []

            @resource.expects(:self_refresh?).returns true
            @resource.expects(:deleting?).returns true
            @transaction.expects(:queue_events_for_resource).never

            @transaction.queue_events(@event)
        end

        it "should ignore edges that don't have a callback" do
            edge1 = stub("edge1", :callback => :nil, :source => stub("s1"), :target => stub("t1", :c1 => nil))

            @graph.expects(:matching_edges).returns [edge1]

            @transaction.expects(:queue_events_for_resource).never

            @transaction.queue_events(@event)
        end

        it "should ignore targets that don't respond to the callback" do
            edge1 = stub("edge1", :callback => :c1, :source => stub("s1"), :target => stub("t1"))

            @graph.expects(:matching_edges).returns [edge1]

            @transaction.expects(:queue_events_for_resource).never

            @transaction.queue_events(@event)
        end
    end

    describe "when queueing events for a resource" do
        before do
            @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
        end

        it "should do nothing if no events are queued" do
            @transaction.queued_events(stub("target")) { |callback, events| raise "should never reach this" }
        end

        it "should yield the callback and events for each callback" do
            target = stub("target")

            2.times do |i|
                @transaction.queue_events_for_resource(stub("source", :info => nil), target, "callback#{i}", ["event#{i}"])
            end

            @transaction.queued_events(target) { |callback, events| }
        end

        it "should use the source to log that it's scheduling a refresh of the target" do
            target = stub("target")
            source = stub 'source'
            source.expects(:info)

            @transaction.queue_events_for_resource(source, target, "callback", ["event"])

            @transaction.queued_events(target) { |callback, events| }
        end
    end

    describe "when processing events for a given resource" do
        before do
            @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
            @transaction.stubs(:queue_events)

            @resource = stub 'resource', :notice => nil
            @event = Puppet::Transaction::Event.new(:event, @resource)
        end

        it "should call the required callback once for each set of associated events" do
            @transaction.expects(:queued_events).with(@resource).multiple_yields([:callback1, [@event]], [:callback2, [@event]])

            @resource.expects(:callback1)
            @resource.expects(:callback2)

            @transaction.process_events(@resource)
        end

        it "should update the 'restarted' metric" do
            @transaction.expects(:queued_events).with(@resource).yields(:callback1, [@event])

            @resource.stubs(:callback1)

            @transaction.process_events(@resource)

            @transaction.resourcemetrics[:restarted].should == 1
        end

        it "should queue a 'restarted' event with the resource as the source" do
            @transaction.expects(:queued_events).with(@resource).yields(:callback1, [@event])

            @resource.stubs(:callback1)

            @transaction.expects(:queue_events).with do |event|
                event.name == :restarted and event.resource == @resource
            end

            @transaction.process_events(@resource)
        end

        it "should log that it restarted" do
            @transaction.expects(:queued_events).with(@resource).yields(:callback1, [@event])

            @resource.stubs(:callback1)

            @resource.expects(:notice).with { |msg| msg.include?("Triggered 'callback1'") }

            @transaction.process_events(@resource)
        end

        describe "and the events include a noop event" do
            before do
                @event.stubs(:name).returns :noop
                @transaction.expects(:queued_events).with(@resource).yields(:callback1, [@event])
            end

            it "should log" do
                @resource.expects(:notice).with { |msg| msg.include?("Would have triggered 'callback1'") }

                @transaction.process_events(@resource)
            end

            it "should not call the callback" do
                @resource.expects(:callback1).never

                @transaction.process_events(@resource)
            end

            it "should queue a new noop event" do
                @transaction.expects(:queue_events).with { |event| event.name == :noop and event.resource == @resource }

                @transaction.process_events(@resource)
            end
        end

        describe "and the callback fails" do
            before do
                @resource.expects(:callback1).raises "a failure"
                @resource.stubs(:err)

                @transaction.expects(:queued_events).yields(:callback1, [@event])
            end

            it "should log but not fail" do
                @resource.expects(:err)

                lambda { @transaction.process_events(@resource) }.should_not raise_error
            end

            it "should update the 'failed_restarts' metric" do
                @transaction.process_events(@resource)
                @transaction.resourcemetrics[:failed_restarts].should == 1
            end

            it "should not queue a 'restarted' event" do
                @transaction.expects(:queue_events).never
                @transaction.process_events(@resource)
            end

            it "should not increase the restarted resource count" do
                @transaction.process_events(@resource)
                @transaction.resourcemetrics[:restarted].should == 0
            end
        end
    end

    describe "when initializing" do
        it "should accept a catalog and set an instance variable for it" do
            catalog = stub 'catalog', :vertices => []

            trans = Puppet::Transaction.new(catalog)
            trans.catalog.should == catalog
        end
    end

    describe "when generating resources" do
        it "should finish all resources" do
            generator = stub 'generator', :depthfirst? => true, :tags => []
            resource = stub 'resource', :tag => nil

            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            generator.expects(:generate).returns [resource]

            @catalog.expects(:add_resource).yields(resource)

            resource.expects(:finish)

            @transaction.generate_additional_resources(generator, :generate)
        end

        it "should skip generated resources that conflict with existing resources" do
            generator = mock 'generator', :tags => []
            resource = stub 'resource', :tag => nil

            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            generator.expects(:generate).returns [resource]

            @catalog.expects(:add_resource).raises(Puppet::Resource::Catalog::DuplicateResourceError.new("foo"))

            resource.expects(:finish).never
            resource.expects(:info) # log that it's skipped

            @transaction.generate_additional_resources(generator, :generate).should be_empty
        end

        it "should copy all tags to the newly generated resources" do
            child = stub 'child'
            generator = stub 'resource', :tags => ["one", "two"]

            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            generator.stubs(:generate).returns [child]
            @catalog.stubs(:add_resource)

            child.expects(:tag).with("one", "two")

            @transaction.generate_additional_resources(generator, :generate)
        end
    end

    describe "when skipping a resource" do
        before :each do
            @resource = stub_everything 'res'
            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)
        end

        it "should skip resource with missing tags" do
            @transaction.stubs(:missing_tags?).returns(true)
            @transaction.skip?(@resource).should be_true
        end

        it "should ask the resource if it's tagged with any of the tags" do
            tags = ['one', 'two']
            @transaction.stubs(:ignore_tags?).returns(false)
            @transaction.stubs(:tags).returns(tags)

            @resource.expects(:tagged?).with(*tags).returns(true)

            @transaction.missing_tags?(@resource).should be_false
        end

        it "should skip not scheduled resources" do
            @transaction.stubs(:scheduled?).returns(false)
            @transaction.skip?(@resource).should be_true
        end

        it "should skip resources with failed dependencies" do
            @transaction.stubs(:failed_dependencies?).returns(false)
            @transaction.skip?(@resource).should be_true
        end

        it "should skip virtual resource" do
            @resource.stubs(:virtual?).returns true
            @transaction.skip?(@resource).should be_true
        end
    end

    describe "when adding metrics to a report" do
        before do
            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            @report = stub 'report', :newmetric => nil, :time= => nil
        end

        [:resources, :time, :changes].each do |metric|
            it "should add times for '#{metric}'" do
                @report.expects(:newmetric).with { |m, v| m == metric }
                @transaction.add_metrics_to_report(@report)
            end
        end

        it "should set the transaction time to the current time" do
            Time.expects(:now).returns "now"
            @report.expects(:time=).with("now")
            @transaction.add_metrics_to_report(@report)
        end
    end

    describe "when prefetching" do
        it "should match resources by name, not title" do
            @catalog = Puppet::Resource::Catalog.new
            @transaction = Puppet::Transaction.new(@catalog)

            # Have both a title and name
            resource = Puppet::Type.type(:sshkey).create :title => "foo", :name => "bar", :type => :dsa, :key => "eh"
            @catalog.add_resource resource

            resource.provider.class.expects(:prefetch).with("bar" => resource)

            @transaction.prefetch
        end
    end
end

describe Puppet::Transaction, " when determining tags" do
    before do
        @config = Puppet::Resource::Catalog.new
        @transaction = Puppet::Transaction.new(@config)
    end

    it "should default to the tags specified in the :tags setting" do
        Puppet.expects(:[]).with(:tags).returns("one")
        @transaction.tags.should == %w{one}
    end

    it "should split tags based on ','" do
        Puppet.expects(:[]).with(:tags).returns("one,two")
        @transaction.tags.should == %w{one two}
    end

    it "should use any tags set after creation" do
        Puppet.expects(:[]).with(:tags).never
        @transaction.tags = %w{one two}
        @transaction.tags.should == %w{one two}
    end

    it "should always convert assigned tags to an array" do
        @transaction.tags = "one::two"
        @transaction.tags.should == %w{one::two}
    end

    it "should accept a comma-delimited string" do
        @transaction.tags = "one, two"
        @transaction.tags.should == %w{one two}
    end

    it "should accept an empty string" do
        @transaction.tags = ""
        @transaction.tags.should == []
    end
end
