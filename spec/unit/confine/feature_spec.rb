require 'spec_helper'

require 'puppet/confine/feature'

describe Puppet::Confine::Feature do
  it "should be named :feature" do
    expect(Puppet::Confine::Feature.name).to eq(:feature)
  end

  it "should require a value" do
    expect { Puppet::Confine::Feature.new }.to raise_error(ArgumentError)
  end

  it "should always convert values to an array" do
    expect(Puppet::Confine::Feature.new("/some/file").values).to be_instance_of(Array)
  end

  describe "when testing values" do
    before do
      @confine = Puppet::Confine::Feature.new("myfeature")
      @confine.label = "eh"
    end

    it "should use the Puppet features instance to test validity" do
      Puppet.features.add(:myfeature) do true end
      @confine.valid?
    end

    it "should return true if the feature is present" do
      Puppet.features.add(:myfeature) do true end
      expect(@confine.pass?("myfeature")).to be_truthy
    end

    it "should return false if the value is false" do
      Puppet.features.add(:myfeature) do false end
      expect(@confine.pass?("myfeature")).to be_falsey
    end

    it "should log that a feature is missing" do
      expect(@confine.message("myfeat")).to be_include("missing")
    end
  end

  it "should summarize multiple instances by returning a flattened array of all missing features" do
    confines = []
    confines << Puppet::Confine::Feature.new(%w{one two})
    confines << Puppet::Confine::Feature.new(%w{two})
    confines << Puppet::Confine::Feature.new(%w{three four})

    features = double('feature')
    allow(features).to receive(:one?)
    allow(features).to receive(:two?)
    allow(features).to receive(:three?)
    allow(features).to receive(:four?)
    allow(Puppet).to receive(:features).and_return(features)

    expect(Puppet::Confine::Feature.summarize(confines).sort).to eq(%w{one two three four}.sort)
  end
end
