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
                @event = stub 'event', :previous_value= => nil, :desired_value= => nil
                @property.stubs(:event).returns @event
            end

            it "should use the property to create the event" do
                @property.expects(:event).returns @event
                @change.event.should equal(@event)
            end

            it "should set 'previous_value' from the change's 'is'" do
                @event.expects(:previous_value=).with(@change.is)
                @change.event
            end

            it "should set 'desired_value' from the change's 'should'" do
                @event.expects(:desired_value=).with(@change.should)
                @change.event
            end
        end

        describe "and executing" do
            before do
                @event = Puppet::Transaction::Event.new(:myevent)
                @event.stubs(:send_log)
                @change.stubs(:noop?).returns false
                @property.stubs(:event).returns @event

                @property.stub_everything
                @property.stubs(:resource).returns "myresource"
                @property.stubs(:name).returns :myprop
            end

            describe "in noop mode" do
                before { @change.stubs(:noop?).returns true }

                it "should log that it is in noop" do
                    @property.expects(:is_to_s)
                    @property.expects(:should_to_s)

                    @event.expects(:message=).with { |msg| msg.include?("should be") }

                    @change.apply
                end

                it "should produce a :noop event and return" do
                    @property.stub_everything

                    @event.expects(:status=).with("noop")

                    @change.apply.should == @event
                end
            end

            it "should sync the property" do
                @property.expects(:sync)

                @change.apply
            end

            it "should return the default event if syncing the property returns nil" do
                @property.stubs(:sync).returns nil

                @change.expects(:event).with(nil).returns @event

                @change.apply.should == @event
            end

            it "should return the default event if syncing the property returns an empty array" do
                @property.stubs(:sync).returns []

                @change.expects(:event).with(nil).returns @event

                @change.apply.should == @event
            end

            it "should log the change" do
                @property.expects(:sync).returns [:one]

                @event.expects(:send_log)

                @change.apply
            end

            it "should set the event's message to the change log" do
                @property.expects(:change_to_s).returns "my change"
                @change.apply.message.should == "my change"
            end

            it "should set the event's status to 'success'" do
                @change.apply.status.should == "success"
            end

            describe "and the change fails" do
                before { @property.expects(:sync).raises "an exception" }

                it "should catch the exception and log the err" do
                    @event.expects(:send_log)
                    lambda { @change.apply }.should_not raise_error
                end

                it "should mark the event status as 'failure'" do
                    @change.apply.status.should == "failure"
                end

                it "should set the event log to a failure log" do
                    @change.apply.message.should be_include("failed")
                end
            end
        end
    end
end
