#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/confine/false'

describe Puppet::Confine::False do
  it "should be named :false" do
    Puppet::Confine::False.name.should == :false
  end

  it "should require a value" do
    lambda { Puppet::Confine.new }.should raise_error(ArgumentError)
  end

  describe "when testing values" do
    before { @confine = Puppet::Confine::False.new("foo") }

    it "should use the 'pass?' method to test validity" do
      @confine = Puppet::Confine::False.new("foo")
      @confine.label = "eh"
      @confine.expects(:pass?).with("foo")
      @confine.valid?
    end

    it "should return true if the value is false" do
      @confine.pass?(false).should be_true
    end

    it "should return false if the value is not false" do
      @confine.pass?("else").should be_false
    end

    it "should produce a message that a value is true" do
      @confine = Puppet::Confine::False.new("foo")
      @confine.message("eh").should be_include("true")
    end
  end

  it "should be able to produce a summary with the number of incorrectly true values" do
    confine = Puppet::Confine::False.new %w{one two three four}
    confine.expects(:pass?).times(4).returns(true).returns(false).returns(true).returns(false)
    confine.summary.should == 2
  end

  it "should summarize multiple instances by summing their summaries" do
    c1 = mock '1', :summary => 1
    c2 = mock '2', :summary => 2
    c3 = mock '3', :summary => 3

    Puppet::Confine::False.summarize([c1, c2, c3]).should == 6
  end
end
