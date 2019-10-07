require 'spec_helper'

require 'puppet/util/feature'

describe Puppet::Util::Feature do
  before do
    @features = Puppet::Util::Feature.new("features")
    allow(@features).to receive(:warn)
  end

  it "should not call associated code when adding a feature" do
    $loaded_feature = false
    @features.add(:myfeature) { $loaded_feature = true}
    expect($loaded_feature).to eq(false)
  end

  it "should consider a feature absent when the feature load fails" do
    @features.add(:failer) { raise "foo" }
    expect(@features.failer?).to eq(false)
  end

  it "should consider a feature to be absent when the feature load returns false" do
    @features.add(:failer) { false }
    expect(@features.failer?).to eq(false)
  end

  it "should consider a feature to be absent when the feature load returns nil" do
    @features.add(:failer) { nil }
    expect(@features.failer?).to eq(false)
  end

  it "should consider a feature to be present when the feature load returns true" do
    @features.add(:available) { true }
    expect(@features.available?).to eq(true)
  end

  it "should consider a feature to be present when the feature load returns truthy" do
    @features.add(:available) { "yes" }
    expect(@features.available?).to eq(true)
  end

  it "should cache the results of a feature load via code block when the block returns true" do
    $loaded_feature = 0
    @features.add(:myfeature) { $loaded_feature += 1; true }
    @features.myfeature?
    @features.myfeature?
    expect($loaded_feature).to eq(1)
  end

  it "should cache the results of a feature load via code block when the block returns false" do
    $loaded_feature = 0
    @features.add(:myfeature) { $loaded_feature += 1; false }
    @features.myfeature?
    @features.myfeature?
    expect($loaded_feature).to eq(1)
  end

  it "should not cache the results of a feature load via code block when the block returns nil" do
    $loaded_feature = 0
    @features.add(:myfeature) { $loaded_feature += 1; nil }
    @features.myfeature?
    @features.myfeature?
    expect($loaded_feature).to eq(2)
  end

  it "should invalidate the cache for the feature when loading" do
    @features.add(:myfeature) { false }
    expect(@features).not_to be_myfeature
    @features.add(:myfeature)
    expect(@features).to be_myfeature
  end

  it "should support features with libraries" do
    expect { @features.add(:puppet, :libs => %w{puppet}) }.not_to raise_error
  end

  it "should consider a feature to be present if all of its libraries are present" do
    @features.add(:myfeature, :libs => %w{foo bar})
    expect(@features).to receive(:require).with("foo")
    expect(@features).to receive(:require).with("bar")

    expect(@features).to be_myfeature
  end

  it "should log and consider a feature to be absent if any of its libraries are absent" do
    @features.add(:myfeature, :libs => %w{foo bar})
    expect(@features).to receive(:require).with("foo").and_raise(LoadError)
    allow(@features).to receive(:require).with("bar")

    expect(@features).to receive(:debug_once)

    expect(@features).not_to be_myfeature
  end

  it "should change the feature to be present when its libraries become available" do
    @features.add(:myfeature, :libs => %w{foo bar})
    times_feature_require_called = 0
    expect(@features).to receive(:require).twice().with("foo") do
      times_feature_require_called += 1
      if times_feature_require_called == 1
        raise LoadError
      else
        nil
      end
    end
    allow(@features).to receive(:require).with("bar")
    allow(Puppet::Util::RubyGems::Source).to receive(:source).and_return(Puppet::Util::RubyGems::Gems18Source)
    times_clear_paths_called = 0
    allow_any_instance_of(Puppet::Util::RubyGems::Gems18Source).to receive(:clear_paths) { times_clear_paths_called += 1 }

    expect(@features).to receive(:debug_once)

    expect(@features).not_to be_myfeature
    expect(@features).to be_myfeature
    expect(times_clear_paths_called).to eq(3)
  end

  it "should cache load failures when configured to do so" do
    Puppet[:always_retry_plugins] = false

    @features.add(:myfeature, :libs => %w{foo bar})
    expect(@features).to receive(:require).with("foo").and_raise(LoadError)

    expect(@features).not_to be_myfeature
    # second call would cause an expectation exception if 'require' was
    # called a second time
    expect(@features).not_to be_myfeature
  end
end
