#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/confiner'

describe Puppet::Confiner do
  before do
    @object = Object.new
    @object.extend(Puppet::Confiner)
  end

  it "should have a method for defining confines" do
    @object.should respond_to(:confine)
  end

  it "should have a method for returning its confine collection" do
    @object.should respond_to(:confine_collection)
  end

  it "should have a method for testing suitability" do
    @object.should respond_to(:suitable?)
  end

  it "should delegate its confine method to its confine collection" do
    coll = mock 'collection'
    @object.stubs(:confine_collection).returns coll
    coll.expects(:confine).with(:foo => :bar, :bee => :baz)
    @object.confine(:foo => :bar, :bee => :baz)
  end

  it "should create a new confine collection if one does not exist" do
    Puppet::ConfineCollection.expects(:new).with("mylabel").returns "mycoll"
    @object.expects(:to_s).returns "mylabel"
    @object.confine_collection.should == "mycoll"
  end

  it "should reuse the confine collection" do
    @object.confine_collection.should equal(@object.confine_collection)
  end

  describe "when testing suitability" do
    before do
      @coll = mock 'collection'
      @object.stubs(:confine_collection).returns @coll
    end

    it "should return true if the confine collection is valid" do
      @coll.expects(:valid?).returns true
      @object.should be_suitable
    end

    it "should return false if the confine collection is invalid" do
      @coll.expects(:valid?).returns false
      @object.should_not be_suitable
    end

    it "should return the summary of the confine collection if a long result is asked for" do
      @coll.expects(:summary).returns "myresult"
      @object.suitable?(false).should == "myresult"
    end
  end
end
