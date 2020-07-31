require 'spec_helper'

require 'puppet/confine'

describe Puppet::Confine do
  it "should require a value" do
    expect { Puppet::Confine.new }.to raise_error(ArgumentError)
  end

  it "should always convert values to an array" do
    expect(Puppet::Confine.new("/some/file").values).to be_instance_of(Array)
  end

  it "should have a 'true' test" do
    expect(Puppet::Confine.test(:true)).to be_instance_of(Class)
  end

  it "should have a 'false' test" do
    expect(Puppet::Confine.test(:false)).to be_instance_of(Class)
  end

  it "should have a 'feature' test" do
    expect(Puppet::Confine.test(:feature)).to be_instance_of(Class)
  end

  it "should have an 'exists' test" do
    expect(Puppet::Confine.test(:exists)).to be_instance_of(Class)
  end

  it "should have a 'variable' test" do
    expect(Puppet::Confine.test(:variable)).to be_instance_of(Class)
  end

  describe "when testing all values" do
    before do
      @confine = Puppet::Confine.new(%w{a b c})
      @confine.label = "foo"
    end

    it "should be invalid if any values fail" do
      allow(@confine).to receive(:pass?).and_return(true)
      expect(@confine).to receive(:pass?).with("b").and_return(false)
      expect(@confine).not_to be_valid
    end

    it "should be valid if all values pass" do
      allow(@confine).to receive(:pass?).and_return(true)
      expect(@confine).to be_valid
    end

    it "should short-cut at the first failing value" do
      expect(@confine).to receive(:pass?).once.and_return(false)
      @confine.valid?
    end

    it "should log failing confines with the label and message" do
      Puppet[:log_level] = 'debug'
      allow(@confine).to receive(:pass?).and_return(false)
      expect(@confine).to receive(:message).and_return("My message")
      expect(@confine).to receive(:label).and_return("Mylabel")
      expect(Puppet).to receive(:debug) { |&b| expect(b.call).to eq("Mylabel: My message") }
      @confine.valid?
    end
  end

  describe "when testing the result of the values" do
    before { @confine = Puppet::Confine.new(%w{a b c d}) }

    it "should return an array with the result of the test for each value" do
      allow(@confine).to receive(:pass?).and_return(true)
      expect(@confine).to receive(:pass?).with("b").and_return(false)
      expect(@confine).to receive(:pass?).with("d").and_return(false)

      expect(@confine.result).to eq([true, false, true, false])
    end
  end

  describe "when requiring" do
    it "does not cache failed requires when always_retry_plugins is true" do
      Puppet[:always_retry_plugins] = true
      expect(Puppet::Confine).to receive(:require).with('puppet/confine/osfamily').twice.and_raise(LoadError)
      Puppet::Confine.test(:osfamily)
      Puppet::Confine.test(:osfamily)
    end

    it "caches failed requires when always_retry_plugins is false" do
      Puppet[:always_retry_plugins] = false
      expect(Puppet::Confine).to receive(:require).with('puppet/confine/osfamily').once.and_raise(LoadError)
      Puppet::Confine.test(:osfamily)
      Puppet::Confine.test(:osfamily)
    end
  end
end
