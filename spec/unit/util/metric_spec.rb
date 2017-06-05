#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/metric'

describe Puppet::Util::Metric do
  before do
    @metric = Puppet::Util::Metric.new("foo")
  end

  [:type, :name, :value, :label].each do |name|
    it "should have a #{name} attribute" do
      expect(@metric).to respond_to(name)
      expect(@metric).to respond_to(name.to_s + "=")
    end
  end

  it "should require a name at initialization" do
    expect { Puppet::Util::Metric.new }.to raise_error(ArgumentError)
  end

  it "should always convert its name to a string" do
    expect(Puppet::Util::Metric.new(:foo).name).to eq("foo")
  end

  it "should support a label" do
    expect(Puppet::Util::Metric.new("foo", "mylabel").label).to eq("mylabel")
  end

  it "should autogenerate a label if none is provided" do
    expect(Puppet::Util::Metric.new("foo_bar").label).to eq("Foo bar")
  end

  it "should have a method for adding values" do
    expect(@metric).to respond_to(:newvalue)
  end

  it "should have a method for returning values" do
    expect(@metric).to respond_to(:values)
  end

  it "should require a name and value for its values" do
    expect { @metric.newvalue }.to raise_error(ArgumentError)
  end

  it "should support a label for values" do
    @metric.newvalue("foo", 10, "label")
    expect(@metric.values[0][1]).to eq("label")
  end

  it "should autogenerate value labels if none is provided" do
    @metric.newvalue("foo_bar", 10)
    expect(@metric.values[0][1]).to eq("Foo bar")
  end

  it "should return its values sorted by label" do
    @metric.newvalue("foo", 10, "b")
    @metric.newvalue("bar", 10, "a")

    expect(@metric.values).to eq([["bar", "a", 10], ["foo", "b", 10]])
  end

  it "should use an array indexer method to retrieve individual values" do
    @metric.newvalue("foo", 10)
    expect(@metric["foo"]).to eq(10)
  end

  it "should return nil if the named value cannot be found" do
    expect(@metric["foo"]).to eq(0)
  end

  let(:metric) do
    metric = Puppet::Util::Metric.new("foo", "mylabel")
    metric.newvalue("v1", 10.1, "something")
    metric.newvalue("v2", 20, "something else")
    metric
  end

  it "should round trip through json" do
    tripped = Puppet::Util::Metric.from_data_hash(JSON.parse(metric.to_json))

    expect(tripped.name).to eq(metric.name)
    expect(tripped.label).to eq(metric.label)
    expect(tripped.values).to eq(metric.values)
  end

  it 'to_data_hash returns value that is instance of to Data' do
    expect(Puppet::Pops::Types::TypeFactory.data.instance?(metric.to_data_hash)).to be_truthy
  end
end
