#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transaction/change'

describe Puppet::Transaction::Change do
    Change = Puppet::Transaction::Change

    describe "when initializing" do
        before do
            @property = stub 'property', :path => "/property/path", :should => "shouldval"
        end

        it "should require the property and current value" do
            lambda { Change.new() }.should raise_error
        end

        it "should set its property to the provided property" do
            Change.new(@property, "value").property.should == :property
        end

        it "should set its 'is' value to the provided value" do
            Change.new(@property, "value").is.should == "value"
        end

        it "should retrieve the 'should' value from the property" do
            # Yay rspec :)
            Change.new(@property, "value").should.should == @property.should
        end
    end

    describe "when an instance" do
        before do
            @property = stub 'property', :path => "/property/path", :should => "shouldval"
            @change = Change.new(@property, "value")
        end

        it "should be noop if the property is noop" do
            @property.expects(:noop).returns true
            @change.noop?.should be_true
        end

        it "should set its resource to the proxy if it has one" do
            @change.proxy = :myresource
            @change.resource.should == :myresource
        end

        it "should set its resource to the property's resource if no proxy is set" do
            @property.expects(:resource).returns :myresource
            @change.resource.should == :myresource
        end

        describe "and creating an event" do
            before do
                @resource = stub 'resource', :ref => "My[resource]"
                @property.stubs(:resource).returns @resource
                @property.stubs(:name).returns :myprop
            end

            it "should set the event name to the provided name" do
                @change.event(:foo).name.should == :foo
            end

            it "should use the property's default event if the event name is nil" do
                @property.expects(:default_event_name).with(@change.should).returns :myevent
                @change.event(nil).name.should == :myevent
            end

            it "should produce a warning if the event name is not a symbol" do
                @property.expects(:warning)
                @property.stubs(:default_event_name).returns :myevent
                @change.event("a string")
            end

            it "should use the property to generate the event name if the provided name is not a symbol" do
                @property.stubs(:warning)
                @property.expects(:default_event_name).with(@change.should).returns :myevent

                @change.event("a string").name.should == :myevent
            end

            it "should set the resource to the resource reference" do
                @change.resource.expects(:ref).returns "Foo[bar]"
                @change.event(:foo).resource.should == "Foo[bar]"
            end

            it "should set the property to the property name" do
                @change.property.expects(:name).returns :myprop
                @change.event(:foo).property.should == :myprop
            end

            it "should set 'previous_value' from the change's 'is'" do
                @change.event(:foo).previous_value.should == @change.is
            end

            it "should set 'desired_value' from the change's 'should'" do
                @change.event(:foo).desired_value.should == @change.should
            end
        end

        describe "and executing" do
            before do
                @event = Puppet::Transaction::Event.new(:myevent)
                @change.stubs(:noop?).returns false
                @change.stubs(:event).returns @event

                @property.stub_everything
                @property.stubs(:resource).returns "myresource"
                @property.stubs(:name).returns :myprop
            end

            describe "in noop mode" do
                before { @change.stubs(:noop?).returns true }

                it "should log that it is in noop" do
                    @property.expects(:is_to_s)
                    @property.expects(:should_to_s)
                    @property.expects(:log)

                    @change.stubs :event
                    @change.forward
                end

                it "should produce a :noop event and return" do
                    @property.stub_everything

                    @change.expects(:event).with(:noop).returns :noop_event

                    @change.forward.should == :noop_event
                end
            end

            it "should sync the property" do
                @property.expects(:sync)

                @change.forward
            end

            it "should return the default event if syncing the property returns nil" do
                @property.stubs(:sync).returns nil

                @change.expects(:event).with(nil).returns @event

                @change.forward.should == @event
            end

            it "should return the default event if syncing the property returns an empty array" do
                @property.stubs(:sync).returns []

                @change.expects(:event).with(nil).returns @event

                @change.forward.should == @event
            end

            it "should log the change" do
                @property.expects(:sync).returns [:one]

                @property.expects(:notice).returns "my log"

                @change.forward
            end

            it "should set the event's log to the log" do
                @property.expects(:notice).returns "my log"
                @change.forward.log.should == "my log"
            end

            it "should set the event's status to 'success'" do
                @change.forward.status.should == "success"
            end

            describe "and the change fails" do
                before { @property.expects(:sync).raises "an exception" }

                it "should catch the exception and log the err" do
                    @property.expects(:err)
                    lambda { @change.forward }.should_not raise_error
                end

                it "should mark the event status as 'failure'" do
                    @change.forward.status.should == "failure"
                end

                it "should set the event log to a failure log" do
                    @property.expects(:err).returns "my failure"
                    @change.forward.log.should == "my failure"
                end
            end

            describe "backward" do
                before do
                    @property = stub 'property'
                    @property.stub_everything
                    @property.stubs(:should).returns "shouldval"
                    @change = Change.new(@property, "value")
                    @change.stubs :go
                end

                it "should swap the 'is' and 'should' values" do
                    @change.backward
                    @change.is.should == "shouldval"
                    @change.should.should == "value"
                end

                it "should set the 'should' value on the property to the previous 'is' value" do
                    @property.expects(:should=).with "value"
                    @change.backward
                end

                it "should log that it's reversing the change" do
                    @property.expects(:info)
                    @change.backward
                end

                it "should execute and return the resulting event" do
                    @change.expects(:go).returns :myevent
                    @change.backward.should == :myevent
                end
            end
        end
    end
end
