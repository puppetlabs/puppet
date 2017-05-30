#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/relationship'

describe Puppet::Relationship do
  before do
    @edge = Puppet::Relationship.new(:a, :b)
  end

  it "should have a :source attribute" do
    expect(@edge).to respond_to(:source)
  end

  it "should have a :target attribute" do
    expect(@edge).to respond_to(:target)
  end

  it "should have a :callback attribute" do
    @edge.callback = :foo
    expect(@edge.callback).to eq(:foo)
  end

  it "should have an :event attribute" do
    @edge.event = :NONE
    expect(@edge.event).to eq(:NONE)
  end

  it "should require a callback if a non-NONE event is specified" do
    expect { @edge.event = :something }.to raise_error(ArgumentError)
  end

  it "should have a :label attribute" do
    expect(@edge).to respond_to(:label)
  end

  it "should provide a :ref method that describes the edge" do
    @edge = Puppet::Relationship.new("a", "b")
    expect(@edge.ref).to eq("a => b")
  end

  it "should be able to produce a label as a hash with its event and callback" do
    @edge.callback = :foo
    @edge.event = :bar

    expect(@edge.label).to eq({:callback => :foo, :event => :bar})
  end

  it "should work if nil options are provided" do
    expect { Puppet::Relationship.new("a", "b", nil) }.not_to raise_error
  end
end

describe Puppet::Relationship, " when initializing" do
  before do
    @edge = Puppet::Relationship.new(:a, :b)
  end

  it "should use the first argument as the source" do
    expect(@edge.source).to eq(:a)
  end

  it "should use the second argument as the target" do
    expect(@edge.target).to eq(:b)
  end

  it "should set the rest of the arguments as the event and callback" do
    @edge = Puppet::Relationship.new(:a, :b, :callback => :foo, :event => :bar)
    expect(@edge.callback).to eq(:foo)
    expect(@edge.event).to eq(:bar)
  end

  it "should accept events specified as strings" do
    @edge = Puppet::Relationship.new(:a, :b, "event" => :NONE)
    expect(@edge.event).to eq(:NONE)
  end

  it "should accept callbacks specified as strings" do
    @edge = Puppet::Relationship.new(:a, :b, "callback" => :foo)
    expect(@edge.callback).to eq(:foo)
  end
end

describe Puppet::Relationship, " when matching edges with no specified event" do
  before do
    @edge = Puppet::Relationship.new(:a, :b)
  end

  it "should not match :NONE" do
    expect(@edge).not_to be_match(:NONE)
  end

  it "should not match :ALL_EVENTS" do
    expect(@edge).not_to be_match(:ALL_EVENTS)
  end

  it "should not match any other events" do
    expect(@edge).not_to be_match(:whatever)
  end
end

describe Puppet::Relationship, " when matching edges with :NONE as the event" do
  before do
    @edge = Puppet::Relationship.new(:a, :b, :event => :NONE)
  end
  it "should not match :NONE" do
    expect(@edge).not_to be_match(:NONE)
  end

  it "should not match :ALL_EVENTS" do
    expect(@edge).not_to be_match(:ALL_EVENTS)
  end

  it "should not match other events" do
    expect(@edge).not_to be_match(:yayness)
  end
end

describe Puppet::Relationship, " when matching edges with :ALL as the event" do
  before do
    @edge = Puppet::Relationship.new(:a, :b, :event => :ALL_EVENTS, :callback => :whatever)
  end

  it "should not match :NONE" do
    expect(@edge).not_to be_match(:NONE)
  end

  it "should match :ALL_EVENTS" do
    expect(@edge).to be_match(:ALL_EVENTS)
  end

  it "should match all other events" do
    expect(@edge).to be_match(:foo)
  end
end

describe Puppet::Relationship, " when matching edges with a non-standard event" do
  before do
    @edge = Puppet::Relationship.new(:a, :b, :event => :random, :callback => :whatever)
  end

  it "should not match :NONE" do
    expect(@edge).not_to be_match(:NONE)
  end

  it "should not match :ALL_EVENTS" do
    expect(@edge).not_to be_match(:ALL_EVENTS)
  end

  it "should match events with the same name" do
    expect(@edge).to be_match(:random)
  end
end

describe Puppet::Relationship, "when converting to json" do
  before do
    @edge = Puppet::Relationship.new('a', 'b', :event => :random, :callback => :whatever)
  end

  it "should store the stringified source as the source in the data" do
    expect(JSON.parse(@edge.to_json)["source"]).to eq("a")
  end

  it "should store the stringified target as the target in the data" do
    expect(JSON.parse(@edge.to_json)['target']).to eq("b")
  end

  it "should store the jsonified event as the event in the data" do
    expect(JSON.parse(@edge.to_json)["event"]).to eq("random")
  end

  it "should not store an event when none is set" do
    @edge.event = nil
    expect(JSON.parse(@edge.to_json)).not_to include('event')
  end

  it "should store the jsonified callback as the callback in the data" do
    @edge.callback = "whatever"
    expect(JSON.parse(@edge.to_json)["callback"]).to eq("whatever")
  end

  it "should not store a callback when none is set in the edge" do
    @edge.callback = nil
    expect(JSON.parse(@edge.to_json)).not_to include('callback')
  end
end

describe Puppet::Relationship, "when converting from json" do
  it "should pass the source in as the first argument" do
    expect(Puppet::Relationship.from_data_hash("source" => "mysource", "target" => "mytarget").source).to eq('mysource')
  end

  it "should pass the target in as the second argument" do
    expect(Puppet::Relationship.from_data_hash("source" => "mysource", "target" => "mytarget").target).to eq('mytarget')
  end

  it "should pass the event as an argument if it's provided" do
    expect(Puppet::Relationship.from_data_hash("source" => "mysource", "target" => "mytarget", "event" => "myevent", "callback" => "eh").event).to eq(:myevent)
  end

  it "should pass the callback as an argument if it's provided" do
    expect(Puppet::Relationship.from_data_hash("source" => "mysource", "target" => "mytarget", "callback" => "mycallback").callback).to eq(:mycallback)
  end
end
