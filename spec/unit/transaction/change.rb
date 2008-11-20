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

        it "should set its path to the path of the property plus 'change'" do
            Change.new(@property, "value").path.should == [@property.path, "change"]
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

        it "should have a method for marking that it's been execution" do
            @change.changed = true
            @change.changed?.should be_true
        end

        describe "and creating an event" do
            before do
                @property.stubs(:resource).returns "myresource"
            end

            it "should produce a warning if the event name is not a symbol" do
                @property.expects(:warning)
                @property.stubs(:event).returns :myevent
                @change.event("a string")
            end

            it "should use the property to generate the event name if the provided name is not a symbol" do
                @property.stubs(:warning)
                @property.expects(:event).with(@change.should).returns :myevent

                Puppet::Transaction::Event.expects(:new).with { |name, source| name == :myevent }

                @change.event("a string")
            end
        end

        describe "and executing" do
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

                    @change.forward.should == [:noop_event]
                end
            end

            describe "without noop" do
                before do
                    @change.stubs(:noop?).returns false
                    @property.stub_everything
                    @property.stubs(:resource).returns "myresource"
                    @property.stubs(:name).returns :myprop
                end

                it "should sync the property" do
                    @property.expects(:sync)

                    @change.forward
                end

                it "should return the default event if syncing the property returns nil" do
                    @property.stubs(:sync).returns nil

                    @change.expects(:event).with(:myprop_changed).returns :myevent

                    @change.forward.should == [:myevent]
                end

                it "should return the default event if syncing the property returns an empty array" do
                    @property.stubs(:sync).returns []

                    @change.expects(:event).with(:myprop_changed).returns :myevent

                    @change.forward.should == [:myevent]
                end

                it "should log the change" do
                    @property.expects(:sync).returns [:one]

                    @property.expects(:log)
                    @property.expects(:change_to_s)

                    @change.forward
                end

                it "should return an array of events" do
                    @property.expects(:sync).returns [:one, :two]

                    @change.expects(:event).with(:one).returns :uno
                    @change.expects(:event).with(:two).returns :dos

                    @change.forward.should == [:uno, :dos]
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

                it "should execute" do
                    @change.expects(:go)
                    @change.backward
                end
            end
        end
    end
end
