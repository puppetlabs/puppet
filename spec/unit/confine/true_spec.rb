#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/confine/true'

describe Puppet::Confine::True do
  it "should be named :true" do
    expect(Puppet::Confine::True.name).to eq(:true)
  end

  it "should require a value" do
    expect { Puppet::Confine::True.new }.to raise_error(ArgumentError)
  end

  describe "when testing values" do
    before do
      @confine = Puppet::Confine::True.new("foo")
      @confine.label = "eh"
    end

    it "should use the 'pass?' method to test validity" do
      @confine.expects(:pass?).with("foo")
      @confine.valid?
    end

    it "should return true if the value is not false" do
      expect(@confine.pass?("else")).to be_truthy
    end

    it "should return false if the value is false" do
      expect(@confine.pass?(nil)).to be_falsey
    end

    it "should produce the message that a value is false" do
      expect(@confine.message("eh")).to be_include("false")
    end
  end

  it "should produce the number of false values when asked for a summary" do
    @confine = Puppet::Confine::True.new %w{one two three four}
    @confine.expects(:pass?).times(4).returns(true).returns(false).returns(true).returns(false)
    expect(@confine.summary).to eq(2)
  end

  it "should summarize multiple instances by summing their summaries" do
    c1 = mock '1', :summary => 1
    c2 = mock '2', :summary => 2
    c3 = mock '3', :summary => 3

    expect(Puppet::Confine::True.summarize([c1, c2, c3])).to eq(6)
  end
end
