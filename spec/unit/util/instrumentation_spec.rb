#! /usr/bin/env ruby

require 'spec_helper'

require 'puppet/util/instrumentation'

describe Puppet::Util::Instrumentation do

  Instrumentation = Puppet::Util::Instrumentation

  after(:each) do
    Instrumentation.clear
  end

  it "should instance-load instrumentation listeners" do
    Instrumentation.instance_loader(:listener).should be_instance_of(Puppet::Util::Autoload)
  end

  it "should have a method for registering instrumentation listeners" do
    Instrumentation.should respond_to(:new_listener)
  end

  it "should have a method for retrieving instrumentation listener by name" do
    Instrumentation.should respond_to(:listener)
  end

  describe "when registering listeners" do
    it "should evaluate the supplied block as code for a class" do
      Instrumentation.expects(:genclass).returns(Class.new { def notify(label, event, data) ; end })
      Instrumentation.new_listener(:testing, :label_pattern => :for_this_label, :event => :all) { }
    end

    it "should subscribe a new listener instance" do
      Instrumentation.expects(:genclass).returns(Class.new { def notify(label, event, data) ; end })
      Instrumentation.new_listener(:testing, :label_pattern => :for_this_label, :event => :all) { }
      Instrumentation.listeners.size.should == 1
      Instrumentation.listeners[0].pattern.should == "for_this_label"
    end

    it "should be possible to access listeners by name" do
      Instrumentation.expects(:genclass).returns(Class.new { def notify(label, event, data) ; end })
      Instrumentation.new_listener(:testing, :label_pattern => :for_this_label, :event => :all) { }
      Instrumentation["testing"].should_not be_nil
    end

    it "should be possible to store a new listener by name" do
      listener = stub 'listener'
      Instrumentation["testing"] = listener
      Instrumentation["testing"].should == listener
    end

    it "should fail if listener is already subscribed" do
      listener = stub 'listener', :notify => nil, :name => "mylistener"
      Instrumentation.subscribe(listener, :for_this_label, :all)
      expect { Instrumentation.subscribe(listener, :for_this_label, :all) }.to raise_error
    end

    it 'should call #unsubscribed' do
      listener = stub 'listener', :notify => nil, :name => "mylistener"

      listener.expects(:subscribed)

      Instrumentation.subscribe(listener, :for_this_label, :all)
    end
  end

  describe "when unsubscribing listener" do
    it "should remove it from the listeners" do
      listener = stub 'listener', :notify => nil, :name => "mylistener"
      Instrumentation.subscribe(listener, :for_this_label, :all)
      Instrumentation.unsubscribe(listener)
      Instrumentation.listeners.size.should == 0
    end

    it "should warn if the listener wasn't subscribed" do
      listener = stub 'listener', :notify => nil, :name => "mylistener"
      Puppet.expects(:warning)
      Instrumentation.unsubscribe(listener)
    end

    it 'should call #unsubscribed' do
      listener = stub 'listener', :notify => nil, :name => "mylistener"
      Instrumentation.subscribe(listener, :for_this_label, :all)

      listener.expects(:unsubscribed)

      Instrumentation.unsubscribe(listener)
    end
  end

  describe "when firing events" do
    it "should be able to find all listeners matching a label" do
      listener = stub 'listener', :notify => nil, :name => "mylistener"
      Instrumentation.subscribe(listener, :for_this_label, :all)
      Instrumentation.listeners[0].enabled = true

      count = 0
      Instrumentation.each_listener(:for_this_label) { |l| count += 1 }
      count.should == 1
    end

    it "should fire events to matching listeners" do
      listener = stub 'listener', :notify => nil, :name => "mylistener"
      Instrumentation.subscribe(listener, :for_this_label, :all)
      Instrumentation.listeners[0].enabled = true

      listener.expects(:notify).with(:for_this_label, :start, {})

      Instrumentation.publish(:for_this_label, :start, {})
    end

    it "should not fire events to non-matching listeners" do
      listener1 = stub 'listener1', :notify => nil, :name => "mylistener1"
      listener2 = stub 'listener2', :notify => nil, :name => "mylistener2"
      Instrumentation.subscribe(listener1, :for_this_label, :all)
      Instrumentation.listeners[0].enabled = true
      Instrumentation.subscribe(listener2, :for_this_other_label, :all)
      Instrumentation.listeners[1].enabled = true

      listener1.expects(:notify).never
      listener2.expects(:notify).with(:for_this_other_label, :start, {})

      Instrumentation.publish(:for_this_other_label, :start, {})
    end
  end

  describe "when instrumenting code" do
    before(:each) do
      Instrumentation.stubs(:publish)
    end
    describe "with a block" do
      it "should execute it" do
        executed = false
        Instrumentation.instrument(:event) do
          executed = true
        end
        executed.should be_true
      end

      it "should publish an event before execution" do
        Instrumentation.expects(:publish).with { |label,event,data| label == :event && event == :start }
        Instrumentation.instrument(:event) {}
      end

      it "should publish an event after execution" do
        Instrumentation.expects(:publish).with { |label,event,data| label == :event && event == :stop }
        Instrumentation.instrument(:event) {}
      end

      it "should publish the event even when block raised an exception" do
        Instrumentation.expects(:publish).with { |label,event,data| label == :event }
        lambda { Instrumentation.instrument(:event) { raise "not working" } }.should raise_error
      end

      it "should retain start end finish time of the event" do
        Instrumentation.expects(:publish).with { |label,event,data| data.include?(:started) and data.include?(:finished) }
        Instrumentation.instrument(:event) {}
      end
    end

    describe "without a block" do
      it "should raise an error if stop is called with no matching start" do
        lambda{ Instrumentation.stop(:event) }.should raise_error
      end

      it "should publish an event on stop" do
        Instrumentation.expects(:publish).with { |label,event,data| event == :start }
        Instrumentation.expects(:publish).with { |label,event,data| event == :stop and data.include?(:started) and data.include?(:finished) }
        data = {}
        Instrumentation.start(:event, data)
        Instrumentation.stop(:event, 1, data)
      end

      it "should return a different id per event" do
        data = {}
        Instrumentation.start(:event, data).should == 1
        Instrumentation.start(:event, data).should == 2
      end
    end
  end
end
