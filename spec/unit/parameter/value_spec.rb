#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/parameter'

describe Puppet::Parameter::Value do
  it "should require a name" do
    lambda { Puppet::Parameter::Value.new }.should raise_error(ArgumentError)
  end

  it "should set its name" do
    Puppet::Parameter::Value.new(:foo).name.should == :foo
  end

  it "should support regexes as names" do
    lambda { Puppet::Parameter::Value.new(%r{foo}) }.should_not raise_error
  end

  it "should mark itself as a regex if its name is a regex" do
    Puppet::Parameter::Value.new(%r{foo}).should be_regex
  end

  it "should always convert its name to a symbol if it is not a regex" do
    Puppet::Parameter::Value.new("foo").name.should == :foo
    Puppet::Parameter::Value.new(true).name.should == :true
  end

  it "should support adding aliases" do
    Puppet::Parameter::Value.new("foo").should respond_to(:alias)
  end

  it "should be able to return its aliases" do
    value = Puppet::Parameter::Value.new("foo")
    value.alias("bar")
    value.alias("baz")
    value.aliases.should == [:bar, :baz]
  end

  [:block, :call, :method, :event, :required_features].each do |attr|
    it "should support a #{attr} attribute" do
      value = Puppet::Parameter::Value.new("foo")
      value.should respond_to(attr.to_s + "=")
      value.should respond_to(attr)
    end
  end

  it "should default to :instead for :call if a block is provided" do
    Puppet::Parameter::Value.new("foo").call.should == :instead
  end

  it "should always return events as symbols" do
    value = Puppet::Parameter::Value.new("foo")
    value.event = "foo_test"
    value.event.should == :foo_test
  end

  describe "when matching" do
    describe "a regex" do
      it "should return true if the regex matches the value" do
        Puppet::Parameter::Value.new(/\w/).should be_match("foo")
      end

      it "should return false if the regex does not match the value" do
        Puppet::Parameter::Value.new(/\d/).should_not be_match("foo")
      end
    end

    describe "a non-regex" do
      it "should return true if the value, converted to a symbol, matches the name" do
        Puppet::Parameter::Value.new("foo").should be_match("foo")
        Puppet::Parameter::Value.new(:foo).should be_match(:foo)
        Puppet::Parameter::Value.new(:foo).should be_match("foo")
        Puppet::Parameter::Value.new("foo").should be_match(:foo)
      end

      it "should return false if the value, converted to a symbol, does not match the name" do
        Puppet::Parameter::Value.new(:foo).should_not be_match(:bar)
      end

      it "should return true if any of its aliases match" do
        value = Puppet::Parameter::Value.new("foo")
        value.alias("bar")
        value.should be_match("bar")
      end
    end
  end
end
