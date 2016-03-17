#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/metric'

describe Puppet::Util::Metric do
  before do
    @metric = Puppet::Util::Metric.new("foo")
  end

  it "should be aliased to Puppet::Metric" do
    Puppet::Util::Metric.should equal(Puppet::Metric)
  end

  [:type, :name, :value, :label, :basedir].each do |name|
    it "should have a #{name} attribute" do
      @metric.should respond_to(name)
      @metric.should respond_to(name.to_s + "=")
    end
  end

  it "should default to the :rrdir as the basedir "do
    rrddir = File.expand_path("myrrd")
    Puppet[:rrddir] = rrddir
    @metric.basedir.should == rrddir
  end

  it "should use any provided basedir" do
    @metric.basedir = "foo"
    @metric.basedir.should == "foo"
  end

  it "should require a name at initialization" do
    lambda { Puppet::Util::Metric.new }.should raise_error(ArgumentError)
  end

  it "should always convert its name to a string" do
    Puppet::Util::Metric.new(:foo).name.should == "foo"
  end

  it "should support a label" do
    Puppet::Util::Metric.new("foo", "mylabel").label.should == "mylabel"
  end

  it "should autogenerate a label if none is provided" do
    Puppet::Util::Metric.new("foo_bar").label.should == "Foo bar"
  end

  it "should have a method for adding values" do
    @metric.should respond_to(:newvalue)
  end

  it "should have a method for returning values" do
    @metric.should respond_to(:values)
  end

  it "should require a name and value for its values" do
    lambda { @metric.newvalue }.should raise_error(ArgumentError)
  end

  it "should support a label for values" do
    @metric.newvalue("foo", 10, "label")
    @metric.values[0][1].should == "label"
  end

  it "should autogenerate value labels if none is provided" do
    @metric.newvalue("foo_bar", 10)
    @metric.values[0][1].should == "Foo bar"
  end

  it "should return its values sorted by label" do
    @metric.newvalue("foo", 10, "b")
    @metric.newvalue("bar", 10, "a")

    @metric.values.should == [["bar", "a", 10], ["foo", "b", 10]]
  end

  it "should use an array indexer method to retrieve individual values" do
    @metric.newvalue("foo", 10)
    @metric["foo"].should == 10
  end

  it "should return nil if the named value cannot be found" do
    @metric["foo"].should == 0
  end

  it "should round trip through pson" do
    metric = Puppet::Util::Metric.new("foo", "mylabel")
    metric.newvalue("v1", 10.1, "something")
    metric.newvalue("v2", 20, "something else")

    tripped = Puppet::Util::Metric.from_data_hash(PSON.parse(metric.to_pson))

    tripped.name.should == metric.name
    tripped.label.should == metric.label
    tripped.values.should == metric.values
  end
end
