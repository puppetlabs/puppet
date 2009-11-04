#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/transaction'

describe Puppet::Transaction do
    it "should delegate its event list to the event manager" do
        @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
        @transaction.event_manager.expects(:events).returns %w{my events}
        @transaction.events.should == %w{my events}
    end

    describe "when initializing" do
        it "should create an event manager" do
            @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
            @transaction.event_manager.should be_instance_of(Puppet::Transaction::EventManager)
            @transaction.event_manager.transaction.should equal(@transaction)
        end
    end

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
            @transaction.event_manager.expects(:process_events).with(@resource)

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
            @transaction.event_manager.stubs(:queue_event)

            @resource = stub 'resource'
            @property = stub 'property', :is_to_s => "is", :should_to_s => "should"

            @event = stub 'event', :status => "success"
            @change = stub 'change', :property => @property, :changed= => nil, :forward => @event, :is => "is", :should => "should"
        end

        it "should apply each change" do
            c1 = stub 'c1', :property => @property, :changed= => nil
            c1.expects(:forward).returns @event
            c2 = stub 'c2', :property => @property, :changed= => nil
            c2.expects(:forward).returns @event

            @transaction.apply_changes(@resource, [c1, c2])
        end

        it "should queue the events from each change" do
            c1 = stub 'c1', :forward => stub("event1", :status => "success"), :property => @property, :changed= => nil
            c2 = stub 'c2', :forward => stub("event2", :status => "success"), :property => @property, :changed= => nil

            @transaction.event_manager.expects(:queue_event).with(@resource, c1.forward)
            @transaction.event_manager.expects(:queue_event).with(@resource, c2.forward)

            @transaction.apply_changes(@resource, [c1, c2])
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
                @event.stubs(:status).returns "failure"
            end

            it "should increment the failures" do
                @transaction.apply_changes(@resource, [@change])
                @transaction.should be_any_failed
            end

            it "should queue the event" do
                @transaction.event_manager.expects(:queue_event).with(@resource, @event)
                @transaction.apply_changes(@resource, [@change])
            end
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
