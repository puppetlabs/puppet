#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/provider/confine/feature'

describe Puppet::Provider::Confine::Feature do
  it "should be named :feature" do
    Puppet::Provider::Confine::Feature.name.should == :feature
  end

  it "should require a value" do
    lambda { Puppet::Provider::Confine::Feature.new }.should raise_error(ArgumentError)
  end

  it "should always convert values to an array" do
    Puppet::Provider::Confine::Feature.new("/some/file").values.should be_instance_of(Array)
  end

  describe "when testing values" do
    before do
      @features = mock 'features'
      Puppet.stubs(:features).returns @features
      @confine = Puppet::Provider::Confine::Feature.new("myfeature")
      @confine.label = "eh"
    end

    it "should use the Puppet features instance to test validity" do
      @features.expects(:myfeature?)
      @confine.valid?
    end

    it "should return true if the feature is present" do
      @features.expects(:myfeature?).returns true
      @confine.pass?("myfeature").should be_true
    end

    it "should return false if the value is false" do
      @features.expects(:myfeature?).returns false
      @confine.pass?("myfeature").should be_false
    end

    it "should log that a feature is missing" do
      @confine.message("myfeat").should be_include("missing")
    end
  end

  it "should summarize multiple instances by returning a flattened array of all missing features" do
    confines = []
    confines << Puppet::Provider::Confine::Feature.new(%w{one two})
    confines << Puppet::Provider::Confine::Feature.new(%w{two})
    confines << Puppet::Provider::Confine::Feature.new(%w{three four})

    features = mock 'feature'
    features.stub_everything
    Puppet.stubs(:features).returns features

    Puppet::Provider::Confine::Feature.summarize(confines).sort.should == %w{one two three four}.sort
  end
end
