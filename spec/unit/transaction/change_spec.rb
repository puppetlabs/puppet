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
      lambda { Change.new }.should raise_error
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
      @property = stub 'property', :path => "/property/path", :should => "shouldval", :is_to_s => 'formatted_property'
      @change = Change.new(@property, "value")
    end

    it "should be noop if the property is noop" do
      @property.expects(:noop).returns true
      @change.noop?.should be_true
    end

    it "should be auditing if set so" do
      @change.auditing = true
      @change.must be_auditing
    end

    it "should set its resource to the proxy if it has one" do
      @change.proxy = :myresource
      @change.resource.should == :myresource
    end

    it "should set its resource to the property's resource if no proxy is set" do
      @property.expects(:resource).returns :myresource
      @change.resource.should == :myresource
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
          @property.expects(:sync).never.never.never.never.never # VERY IMPORTANT

          @event.expects(:status=).with("noop")

          @change.apply.should == @event
        end
      end

      describe "in audit mode" do
        before do 
          @change.auditing = true
          @change.old_audit_value = "old_value"
          @property.stubs(:insync?).returns(true)
        end

        it "should log that it is in audit mode" do
          message = nil
          @event.expects(:message=).with { |msg| message = msg }

          @change.apply
          message.should == "audit change: previously recorded value formatted_property has been changed to formatted_property"
        end

        it "should produce a :audit event and return" do
          @property.stub_everything

          @event.expects(:status=).with("audit")

          @change.apply.should == @event
        end

        it "should mark the historical_value on the event" do
          @property.stub_everything

          @change.apply.historical_value.should == "old_value"
        end
      end

      describe "when syncing and auditing together" do
        before do 
          @change.auditing = true
          @change.old_audit_value = "old_value"
          @property.stubs(:insync?).returns(false)
        end

        it "should sync the property" do
          @property.expects(:sync)

          @change.apply
        end

        it "should produce a success event" do
          @property.stub_everything

          @change.apply.status.should == "success"
        end

        it "should mark the historical_value on the event" do
          @property.stub_everything

          @change.apply.historical_value.should == "old_value"
        end
      end

      it "should sync the property" do
        @property.expects(:sync)

        @change.apply
      end

      it "should return the default event if syncing the property returns nil" do
        @property.stubs(:sync).returns nil

        @property.expects(:event).with(nil).returns @event

        @change.apply.should == @event
      end

      it "should return the default event if syncing the property returns an empty array" do
        @property.stubs(:sync).returns []

        @property.expects(:event).with(nil).returns @event

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
