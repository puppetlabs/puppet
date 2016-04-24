#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/feature'

describe Puppet::Util::Feature do
  before do
    @features = Puppet::Util::Feature.new("features")
    @features.stubs(:warn)
  end

  it "should be able to add new features" do
    @features.add(:myfeature) {}
    expect(@features).to respond_to(:myfeature?)
  end

  it "should call associated code when loading a feature" do
    $loaded_feature = false
    @features.add(:myfeature) { $loaded_feature = true}
    expect($loaded_feature).to be_truthy
  end

  it "should consider a feature absent when the feature load fails" do
    @features.add(:failer) { raise "foo" }
    expect(@features).not_to be_failer
  end

  it "should consider a feature to be absent when the feature load returns false" do
    @features.add(:failer) { false }
    expect(@features).not_to be_failer
  end

  it "should consider a feature to be present when the feature load returns true" do
    @features.add(:available) { true }
    expect(@features).to be_available
  end

  it "should cache the results of a feature load via code block" do
    $loaded_feature = 0
    @features.add(:myfeature) { $loaded_feature += 1 }
    @features.myfeature?
    @features.myfeature?
    expect($loaded_feature).to eq(1)
  end

  it "should invalidate the cache for the feature when loading" do
    # block defined features are evaluated at load time
    @features.add(:myfeature) { false }
    expect(@features).not_to be_myfeature
    # features with no block have deferred evaluation so an existing cached
    # value would take precedence
    @features.add(:myfeature)
    expect(@features).to be_myfeature
  end

  it "should support features with libraries" do
    expect { @features.add(:puppet, :libs => %w{puppet}) }.not_to raise_error
  end

  it "should consider a feature to be present if all of its libraries are present" do
    @features.add(:myfeature, :libs => %w{foo bar})
    @features.expects(:require).with("foo")
    @features.expects(:require).with("bar")

    expect(@features).to be_myfeature
  end

  it "should log and consider a feature to be absent if any of its libraries are absent" do
    @features.add(:myfeature, :libs => %w{foo bar})
    @features.expects(:require).with("foo").raises(LoadError)
    @features.stubs(:require).with("bar")

    Puppet.expects(:debug)

    expect(@features).not_to be_myfeature
  end

  it "should change the feature to be present when its libraries become available" do
    @features.add(:myfeature, :libs => %w{foo bar})
    @features.expects(:require).twice().with("foo").raises(LoadError).then.returns(nil)
    @features.stubs(:require).with("bar")
    Puppet::Util::RubyGems::Source.stubs(:source).returns(Puppet::Util::RubyGems::OldGemsSource)
    Puppet::Util::RubyGems::OldGemsSource.any_instance.expects(:clear_paths).times(3)

    Puppet.expects(:debug)

    expect(@features).not_to be_myfeature
    expect(@features).to be_myfeature
  end

  it "should cache load failures when configured to do so" do
    Puppet[:always_retry_plugins] = false

    @features.add(:myfeature, :libs => %w{foo bar})
    @features.expects(:require).with("foo").raises(LoadError)

    expect(@features).not_to be_myfeature
    # second call would cause an expectation exception if 'require' was
    # called a second time
    expect(@features).not_to be_myfeature
  end
end
