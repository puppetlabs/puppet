#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Adaptable::Adapter do
  class ValueAdapter < Puppet::Pops::Adaptable::Adapter
    attr_accessor :value
  end

  class OtherAdapter < Puppet::Pops::Adaptable::Adapter
    attr_accessor :value
    def OtherAdapter.create_adapter(o)
      x = new
      x.value="I am calling you Daffy."
      x
    end
  end

  module Farm
    class FarmAdapter < Puppet::Pops::Adaptable::Adapter
      attr_accessor :value
    end
  end

  class Duck
    include Puppet::Pops::Adaptable
  end

  it "should create specialized adapter instance on call to adapt" do
    d = Duck.new
    a = ValueAdapter.adapt(d)
    a.class.should == ValueAdapter
  end

  it "should produce the same instance on multiple adaptations" do
    d = Duck.new
    a = ValueAdapter.adapt(d)
    a.value = 10
    b = ValueAdapter.adapt(d)
    b.value.should == 10
  end

  it "should return the correct adapter if there are several" do
    d = Duck.new
    other = OtherAdapter.adapt(d)
    a = ValueAdapter.adapt(d)
    a.value = 10
    b = ValueAdapter.adapt(d)
    b.value.should == 10
  end

  it "should allow specialization to override creating" do
    d = Duck.new
    a = OtherAdapter.adapt(d)
    a.value.should == "I am calling you Daffy."
  end

  it "should create a new adapter overriding existing" do
    d = Duck.new
    a = OtherAdapter.adapt(d)
    a.value.should == "I am calling you Daffy."
    a.value = "Something different"
    a.value.should == "Something different"
    b = OtherAdapter.adapt(d)
    b.value.should == "Something different"
    b = OtherAdapter.adapt_new(d)
    b.value.should == "I am calling you Daffy."
  end

  it "should not create adapter on get" do
    d = Duck.new
    a = OtherAdapter.get(d)
    a.should == nil
  end

  it "should return same adapter from get after adapt" do
    d = Duck.new
    a = OtherAdapter.get(d)
    a.should == nil
    a = OtherAdapter.adapt(d)
    a.value.should == "I am calling you Daffy."
    b = OtherAdapter.get(d)
    b.value.should == "I am calling you Daffy."
    a.should == b
  end

  it "should handle adapters in nested namespaces" do
    d = Duck.new
    a = Farm::FarmAdapter.get(d)
    a.should == nil
    a = Farm::FarmAdapter.adapt(d)
    a.value = 10
    b = Farm::FarmAdapter.get(d)
    b.value.should == 10
  end

  it "should be able to clear the adapter" do
    d = Duck.new
    a = OtherAdapter.adapt(d)
    a.value.should == "I am calling you Daffy."
    # The adapter cleared should be returned
    OtherAdapter.clear(d).value.should == "I am calling you Daffy."
    OtherAdapter.get(d).should == nil
  end

  context "When adapting with #adapt it" do
    it "should be possible to pass a block to configure the adapter" do
      d = Duck.new
      a = OtherAdapter.adapt(d) do |x|
        x.value = "Donald"
      end
      a.value.should == "Donald"
    end

    it "should be possible to pass a block to configure the adapter and get the adapted" do
      d = Duck.new
      a = OtherAdapter.adapt(d) do |x, o|
        x.value = "Donald, the #{o.class.name}"
      end
      a.value.should == "Donald, the Duck"
    end
  end

  context "When adapting with #adapt_new it" do
    it "should be possible to pass a block to configure the adapter" do
      d = Duck.new
      a = OtherAdapter.adapt_new(d) do |x|
        x.value = "Donald"
      end
      a.value.should == "Donald"
    end

    it "should be possible to pass a block to configure the adapter and get the adapted" do
      d = Duck.new
      a = OtherAdapter.adapt_new(d) do |x, o|
        x.value = "Donald, the #{o.class.name}"
      end
      a.value.should == "Donald, the Duck"
    end
  end
end
