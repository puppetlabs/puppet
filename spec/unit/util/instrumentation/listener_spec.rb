#! /usr/bin/env ruby

require 'spec_helper'
require 'matchers/json'

require 'puppet/util/instrumentation'
require 'puppet/util/instrumentation/listener'

describe Puppet::Util::Instrumentation::Listener do
  include JSONMatchers

  Listener = Puppet::Util::Instrumentation::Listener

  before(:each) do
    @delegate = stub 'listener', :notify => nil, :name => 'listener'
    @listener = Listener.new(@delegate)
    @listener.enabled = true
  end

  it "should indirect instrumentation_listener" do
    Listener.indirection.name.should == :instrumentation_listener
  end

  it "should raise an error if delegate doesn't support notify" do
    lambda { Listener.new(Object.new) }.should raise_error
  end

  it "should not be enabled by default" do
    Listener.new(@delegate).should_not be_enabled
  end

  it "should delegate notification" do
    @delegate.expects(:notify).with(:event, :start, {})
    listener = Listener.new(@delegate)
    listener.notify(:event, :start, {})
  end

  it "should not listen is not enabled" do
    @listener.enabled = false
    @listener.should_not be_listen_to(:label)
  end

  it "should listen to all label if created without pattern" do
    @listener.should be_listen_to(:improbable_label)
  end

  it "should listen to specific string pattern" do
    listener = Listener.new(@delegate, "specific")
    listener.enabled = true
    listener.should be_listen_to(:specific)
  end

  it "should not listen to non-matching string pattern" do
    listener = Listener.new(@delegate, "specific")
    listener.enabled = true
    listener.should_not be_listen_to(:unspecific)
  end

  it "should listen to specific regex pattern" do
    listener = Listener.new(@delegate, /spe.*/)
    listener.enabled = true
    listener.should be_listen_to(:specific_pattern)
  end

  it "should not listen to non matching regex pattern" do
    listener = Listener.new(@delegate, /^match.*/)
    listener.enabled = true
    listener.should_not be_listen_to(:not_matching)
  end

  it "should delegate its name to the underlying listener" do
    @delegate.expects(:name).returns("myname")
    @listener.name.should == "myname"
  end

  it "should delegate data fetching to the underlying listener" do
    @delegate.expects(:data).returns(:data)
    @listener.data.should == {:data => :data }
  end

  describe "when serializing to pson" do
    it "should return a pson object containing pattern, name and status" do
      @listener.should set_json_attribute('enabled').to(true)
      @listener.should set_json_attribute('name').to("listener")
    end
  end

  describe "when deserializing from pson" do
    it "should lookup the archetype listener from the instrumentation layer" do
      Puppet::Util::Instrumentation.expects(:[]).with("listener").returns(@listener)
      Puppet::Util::Instrumentation::Listener.from_data_hash({"name" => "listener"})
    end

    it "should create a new listener shell instance delegating to the archetypal listener" do
      Puppet::Util::Instrumentation.expects(:[]).with("listener").returns(@listener)
      @listener.stubs(:listener).returns(@delegate)
      Puppet::Util::Instrumentation::Listener.expects(:new).with(@delegate, nil, true)
      Puppet::Util::Instrumentation::Listener.from_data_hash({"name" => "listener", "enabled" => true})
    end
  end
end
