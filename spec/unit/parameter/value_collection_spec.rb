#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parameter'

describe Puppet::Parameter::ValueCollection do
  before do
    @collection = Puppet::Parameter::ValueCollection.new
  end

  it "should have a method for defining new values" do
    expect(@collection).to respond_to(:newvalues)
  end

  it "should have a method for adding individual values" do
    expect(@collection).to respond_to(:newvalue)
  end

  it "should be able to retrieve individual values" do
    value = @collection.newvalue(:foo)
    expect(@collection.value(:foo)).to equal(value)
  end

  it "should be able to add an individual value with a block" do
    @collection.newvalue(:foo) { raise "testing" }
    expect(@collection.value(:foo).block).to be_instance_of(Proc)
  end

  it "should be able to add values that are empty strings" do
    expect { @collection.newvalue('') }.to_not raise_error
  end

  it "should be able to add values that are empty strings" do
    value = @collection.newvalue('')
    expect(@collection.match?('')).to equal(value)
  end

  describe "when adding a value with a block" do
    it "should set the method name to 'set_' plus the value name" do
      value = @collection.newvalue(:myval) { raise "testing" }
      expect(value.method).to eq("set_myval")
    end
  end

  it "should be able to add an individual value with options" do
    value = @collection.newvalue(:foo, :method => 'set_myval')
    expect(value.method).to eq('set_myval')
  end

  it "should have a method for validating a value" do
    expect(@collection).to respond_to(:validate)
  end

  it "should have a method for munging a value" do
    expect(@collection).to respond_to(:munge)
  end

  it "should be able to generate documentation when it has both values and regexes" do
    @collection.newvalues :foo, "bar", %r{test}
    expect(@collection.doc).to be_instance_of(String)
  end

  it "should correctly generate documentation for values" do
    @collection.newvalues :foo
    expect(@collection.doc).to be_include("Valid values are `foo`")
  end

  it "should correctly generate documentation for regexes" do
    @collection.newvalues %r{\w+}
    expect(@collection.doc).to be_include("Values can match `/\\w+/`")
  end

  it "should be able to find the first matching value" do
    @collection.newvalues :foo, :bar
    expect(@collection.match?("foo")).to be_instance_of(Puppet::Parameter::Value)
  end

  it "should be able to match symbols" do
    @collection.newvalues :foo, :bar
    expect(@collection.match?(:foo)).to be_instance_of(Puppet::Parameter::Value)
  end

  it "should be able to match symbols when a regex is provided" do
    @collection.newvalues %r{.}
    expect(@collection.match?(:foo)).to be_instance_of(Puppet::Parameter::Value)
  end

  it "should be able to match values using regexes" do
    @collection.newvalues %r{.}
    expect(@collection.match?("foo")).not_to be_nil
  end

  it "should prefer value matches to regex matches" do
    @collection.newvalues %r{.}, :foo
    expect(@collection.match?("foo").name).to eq(:foo)
  end

  describe "when validating values" do
    it "should do nothing if no values or regexes have been defined" do
      @collection.validate("foo")
    end

    it "should fail if the value is not a defined value or alias and does not match a regex" do
      @collection.newvalues :foo
      expect { @collection.validate("bar") }.to raise_error(ArgumentError)
    end

    it "should succeed if the value is one of the defined values" do
      @collection.newvalues :foo
      expect { @collection.validate(:foo) }.to_not raise_error
    end

    it "should succeed if the value is one of the defined values even if the definition uses a symbol and the validation uses a string" do
      @collection.newvalues :foo
      expect { @collection.validate("foo") }.to_not raise_error
    end

    it "should succeed if the value is one of the defined values even if the definition uses a string and the validation uses a symbol" do
      @collection.newvalues "foo"
      expect { @collection.validate(:foo) }.to_not raise_error
    end

    it "should succeed if the value is one of the defined aliases" do
      @collection.newvalues :foo
      @collection.aliasvalue :bar, :foo
      expect { @collection.validate("bar") }.to_not raise_error
    end

    it "should succeed if the value matches one of the regexes" do
      @collection.newvalues %r{\d}
      expect { @collection.validate("10") }.to_not raise_error
    end
  end

  describe "when munging values" do
    it "should do nothing if no values or regexes have been defined" do
      expect(@collection.munge("foo")).to eq("foo")
    end

    it "should return return any matching defined values" do
      @collection.newvalues :foo, :bar
      expect(@collection.munge("foo")).to eq(:foo)
    end

    it "should return any matching aliases" do
      @collection.newvalues :foo
      @collection.aliasvalue :bar, :foo
      expect(@collection.munge("bar")).to eq(:foo)
    end

    it "should return the value if it matches a regex" do
      @collection.newvalues %r{\w}
      expect(@collection.munge("bar")).to eq("bar")
    end

    it "should return the value if no other option is matched" do
      @collection.newvalues :foo
      expect(@collection.munge("bar")).to eq("bar")
    end
  end
end
