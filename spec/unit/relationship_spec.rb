#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/relationship'

describe Puppet::Relationship do
  before do
    @edge = Puppet::Relationship.new(:a, :b)
  end

  it "should have a :source attribute" do
    @edge.should respond_to(:source)
  end

  it "should have a :target attribute" do
    @edge.should respond_to(:target)
  end

  it "should have a :callback attribute" do
    @edge.callback = :foo
    @edge.callback.should == :foo
  end

  it "should have an :event attribute" do
    @edge.event = :NONE
    @edge.event.should == :NONE
  end

  it "should require a callback if a non-NONE event is specified" do
    proc { @edge.event = :something }.should raise_error(ArgumentError)
  end

  it "should have a :label attribute" do
    @edge.should respond_to(:label)
  end

  it "should provide a :ref method that describes the edge" do
    @edge = Puppet::Relationship.new("a", "b")
    @edge.ref.should == "a => b"
  end

  it "should be able to produce a label as a hash with its event and callback" do
    @edge.callback = :foo
    @edge.event = :bar

    @edge.label.should == {:callback => :foo, :event => :bar}
  end

  it "should work if nil options are provided" do
    lambda { Puppet::Relationship.new("a", "b", nil) }.should_not raise_error
  end
end

describe Puppet::Relationship, " when initializing" do
  before do
    @edge = Puppet::Relationship.new(:a, :b)
  end

  it "should use the first argument as the source" do
    @edge.source.should == :a
  end

  it "should use the second argument as the target" do
    @edge.target.should == :b
  end

  it "should set the rest of the arguments as the event and callback" do
    @edge = Puppet::Relationship.new(:a, :b, :callback => :foo, :event => :bar)
    @edge.callback.should == :foo
    @edge.event.should == :bar
  end

  it "should accept events specified as strings" do
    @edge = Puppet::Relationship.new(:a, :b, "event" => :NONE)
    @edge.event.should == :NONE
  end

  it "should accept callbacks specified as strings" do
    @edge = Puppet::Relationship.new(:a, :b, "callback" => :foo)
    @edge.callback.should == :foo
  end
end

describe Puppet::Relationship, " when matching edges with no specified event" do
  before do
    @edge = Puppet::Relationship.new(:a, :b)
  end

  it "should not match :NONE" do
    @edge.should_not be_match(:NONE)
  end

  it "should not match :ALL_EVENTS" do
    @edge.should_not be_match(:NONE)
  end

  it "should not match any other events" do
    @edge.should_not be_match(:whatever)
  end
end

describe Puppet::Relationship, " when matching edges with :NONE as the event" do
  before do
    @edge = Puppet::Relationship.new(:a, :b, :event => :NONE)
  end
  it "should not match :NONE" do
    @edge.should_not be_match(:NONE)
  end

  it "should not match :ALL_EVENTS" do
    @edge.should_not be_match(:ALL_EVENTS)
  end

  it "should not match other events" do
    @edge.should_not be_match(:yayness)
  end
end

describe Puppet::Relationship, " when matching edges with :ALL as the event" do
  before do
    @edge = Puppet::Relationship.new(:a, :b, :event => :ALL_EVENTS, :callback => :whatever)
  end

  it "should not match :NONE" do
    @edge.should_not be_match(:NONE)
  end

  it "should match :ALL_EVENTS" do
    @edge.should be_match(:ALLEVENTS)
  end

  it "should match all other events" do
    @edge.should be_match(:foo)
  end
end

describe Puppet::Relationship, " when matching edges with a non-standard event" do
  before do
    @edge = Puppet::Relationship.new(:a, :b, :event => :random, :callback => :whatever)
  end

  it "should not match :NONE" do
    @edge.should_not be_match(:NONE)
  end

  it "should not match :ALL_EVENTS" do
    @edge.should_not be_match(:ALL_EVENTS)
  end

  it "should match events with the same name" do
    @edge.should be_match(:random)
  end
end

describe Puppet::Relationship, "when converting to pson" do
  before do
    @edge = Puppet::Relationship.new(:a, :b, :event => :random, :callback => :whatever)
  end

  it "should store the stringified source as the source in the data" do
    PSON.parse(@edge.to_pson)["source"].should == "a"
  end

  it "should store the stringified target as the target in the data" do
    PSON.parse(@edge.to_pson)['target'].should == "b"
  end

  it "should store the psonified event as the event in the data" do
    PSON.parse(@edge.to_pson)["event"].should == "random"
  end

  it "should not store an event when none is set" do
    @edge.event = nil
    PSON.parse(@edge.to_pson)["event"].should be_nil
  end

  it "should store the psonified callback as the callback in the data" do
    @edge.callback = "whatever"
    PSON.parse(@edge.to_pson)["callback"].should == "whatever"
  end

  it "should not store a callback when none is set in the edge" do
    @edge.callback = nil
    PSON.parse(@edge.to_pson)["callback"].should be_nil
  end
end

describe Puppet::Relationship, "when converting from pson" do
  before do
    @event = "random"
    @callback = "whatever"
    @data = {
      "source" => "mysource",
      "target" => "mytarget",
      "event" => @event,
      "callback" => @callback
    }
    @pson = {
      "type" => "Puppet::Relationship",
      "data" => @data
    }
  end

  def pson_result_should
    Puppet::Relationship.expects(:new).with { |*args| yield args }
  end

  it "should be extended with the PSON utility module" do
    Puppet::Relationship.singleton_class.ancestors.should be_include(Puppet::Util::Pson)
  end

  # LAK:NOTE For all of these tests, we convert back to the edge so we can
  # trap the actual data structure then.
  it "should pass the source in as the first argument" do
    Puppet::Relationship.from_data_hash("source" => "mysource", "target" => "mytarget").source.should == "mysource"
  end

  it "should pass the target in as the second argument" do
    Puppet::Relationship.from_data_hash("source" => "mysource", "target" => "mytarget").target.should == "mytarget"
  end

  it "should pass the event as an argument if it's provided" do
    Puppet::Relationship.from_data_hash("source" => "mysource", "target" => "mytarget", "event" => "myevent", "callback" => "eh").event.should == "myevent"
  end

  it "should pass the callback as an argument if it's provided" do
    Puppet::Relationship.from_data_hash("source" => "mysource", "target" => "mytarget", "callback" => "mycallback").callback.should == "mycallback"
  end
end
