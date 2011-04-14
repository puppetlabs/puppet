#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/provider/confine'

describe Puppet::Provider::Confine do
  it "should require a value" do
    lambda { Puppet::Provider::Confine.new }.should raise_error(ArgumentError)
  end

  it "should always convert values to an array" do
    Puppet::Provider::Confine.new("/some/file").values.should be_instance_of(Array)
  end

  it "should have a 'true' test" do
    Puppet::Provider::Confine.test(:true).should be_instance_of(Class)
  end

  it "should have a 'false' test" do
    Puppet::Provider::Confine.test(:false).should be_instance_of(Class)
  end

  it "should have a 'feature' test" do
    Puppet::Provider::Confine.test(:feature).should be_instance_of(Class)
  end

  it "should have an 'exists' test" do
    Puppet::Provider::Confine.test(:exists).should be_instance_of(Class)
  end

  it "should have a 'variable' test" do
    Puppet::Provider::Confine.test(:variable).should be_instance_of(Class)
  end

  describe "when testing all values" do
    before do
      @confine = Puppet::Provider::Confine.new(%w{a b c})
      @confine.label = "foo"
    end

    it "should be invalid if any values fail" do
      @confine.stubs(:pass?).returns true
      @confine.expects(:pass?).with("b").returns false
      @confine.should_not be_valid
    end

    it "should be valid if all values pass" do
      @confine.stubs(:pass?).returns true
      @confine.should be_valid
    end

    it "should short-cut at the first failing value" do
      @confine.expects(:pass?).once.returns false
      @confine.valid?
    end

    it "should log failing confines with the label and message" do
      @confine.stubs(:pass?).returns false
      @confine.expects(:message).returns "My message"
      @confine.expects(:label).returns "Mylabel"
      Puppet.expects(:debug).with("Mylabel: My message")
      @confine.valid?
    end
  end

  describe "when testing the result of the values" do
    before { @confine = Puppet::Provider::Confine.new(%w{a b c d}) }

    it "should return an array with the result of the test for each value" do
      @confine.stubs(:pass?).returns true
      @confine.expects(:pass?).with("b").returns false
      @confine.expects(:pass?).with("d").returns false

      @confine.result.should == [true, false, true, false]
    end
  end
end
