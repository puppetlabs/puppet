#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/feature'

describe Puppet::Util::Feature do
  before do
    @features = Puppet::Util::Feature.new("features")
    @features.stubs(:warn)
  end

  it "should consider undefined features to be absent" do
    @features.should_not be_defined_feature
  end

  it "should be able to add new features" do
    @features.add(:myfeature) {}
    @features.should respond_to(:myfeature?)
  end

  it "should call associated code when loading a feature" do
    $loaded_feature = false
    @features.add(:myfeature) { $loaded_feature = true}
    $loaded_feature.should be_true
  end

  it "should consider a feature absent when the feature load fails" do
    @features.add(:failer) { raise "foo" }
    @features.should_not be_failer
  end

  it "should consider a feature to be absent when the feature load returns false" do
    @features.add(:failer) { false }
    @features.should_not be_failer
  end

  it "should consider a feature to be present when the feature load returns true" do
    @features.add(:available) { true }
    @features.should be_available
  end

  it "should cache the results of a feature load" do
    $loaded_feature = 0
    @features.add(:myfeature) { $loaded_feature += 1 }
    @features.myfeature?
    @features.myfeature?
    $loaded_feature.should == 1
  end

  it "should support features with libraries" do
    lambda { @features.add(:puppet, :libs => %w{puppet}) }.should_not raise_error
  end

  it "should consider a feature to be present if all of its libraries are present" do
    @features.add(:myfeature, :libs => %w{foo bar})
    @features.expects(:require).with("foo")
    @features.expects(:require).with("bar")

    @features.should be_myfeature
  end

  it "should log and consider a feature to be absent if any of its libraries are absent" do
    @features.add(:myfeature, :libs => %w{foo bar})
    @features.expects(:require).with("foo").raises(LoadError)
    @features.stubs(:require).with("bar")

    Puppet.expects(:debug)

    @features.should_not be_myfeature
  end
end
