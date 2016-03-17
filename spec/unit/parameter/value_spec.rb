#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parameter'

describe Puppet::Parameter::Value do
  it "should require a name" do
    expect { Puppet::Parameter::Value.new }.to raise_error(ArgumentError)
  end

  it "should set its name" do
    expect(Puppet::Parameter::Value.new(:foo).name).to eq(:foo)
  end

  it "should support regexes as names" do
    expect { Puppet::Parameter::Value.new(%r{foo}) }.not_to raise_error
  end

  it "should mark itself as a regex if its name is a regex" do
    expect(Puppet::Parameter::Value.new(%r{foo})).to be_regex
  end

  it "should always convert its name to a symbol if it is not a regex" do
    expect(Puppet::Parameter::Value.new("foo").name).to eq(:foo)
    expect(Puppet::Parameter::Value.new(true).name).to eq(:true)
  end

  it "should support adding aliases" do
    expect(Puppet::Parameter::Value.new("foo")).to respond_to(:alias)
  end

  it "should be able to return its aliases" do
    value = Puppet::Parameter::Value.new("foo")
    value.alias("bar")
    value.alias("baz")
    expect(value.aliases).to eq([:bar, :baz])
  end

  [:block, :method, :event, :required_features].each do |attr|
    it "should support a #{attr} attribute" do
      value = Puppet::Parameter::Value.new("foo")
      expect(value).to respond_to(attr.to_s + "=")
      expect(value).to respond_to(attr)
    end
  end

  it "should always return events as symbols" do
    value = Puppet::Parameter::Value.new("foo")
    value.event = "foo_test"
    expect(value.event).to eq(:foo_test)
  end

  describe "when matching" do
    describe "a regex" do
      it "should return true if the regex matches the value" do
        expect(Puppet::Parameter::Value.new(/\w/)).to be_match("foo")
      end

      it "should return false if the regex does not match the value" do
        expect(Puppet::Parameter::Value.new(/\d/)).not_to be_match("foo")
      end
    end

    describe "a non-regex" do
      it "should return true if the value, converted to a symbol, matches the name" do
        expect(Puppet::Parameter::Value.new("foo")).to be_match("foo")
        expect(Puppet::Parameter::Value.new(:foo)).to be_match(:foo)
        expect(Puppet::Parameter::Value.new(:foo)).to be_match("foo")
        expect(Puppet::Parameter::Value.new("foo")).to be_match(:foo)
      end

      it "should return false if the value, converted to a symbol, does not match the name" do
        expect(Puppet::Parameter::Value.new(:foo)).not_to be_match(:bar)
      end

      it "should return true if any of its aliases match" do
        value = Puppet::Parameter::Value.new("foo")
        value.alias("bar")
        expect(value).to be_match("bar")
      end
    end
  end
end
