require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/integer_setting'

describe Puppet::Settings::IntegerSetting do
  let(:setting) { described_class.new(:settings => double('settings'), :desc => "test") }

  it "is of type :integer" do
    expect(setting.type).to eq(:integer)
  end

  describe "when munging the setting" do
    it "returns the same value if given a positive integer" do
      expect(setting.munge(5)).to eq(5)
    end

    it "returns the same value if given a negative integer" do
      expect(setting.munge(-25)).to eq(-25)
    end

    it "returns an integer if given a valid integer as string" do
      expect(setting.munge('12')).to eq(12)
    end

    it "returns an integer if given a valid negative integer as string" do
      expect(setting.munge('-12')).to eq(-12)
    end

    it "returns an integer if given a valid positive integer as string" do
      expect(setting.munge('+12')).to eq(12)
    end

    it "raises if given an invalid value" do
      expect { setting.munge('a5') }.to raise_error(Puppet::Settings::ValidationError)
    end

    it "raises if given nil" do
      expect { setting.munge(nil) }.to raise_error(Puppet::Settings::ValidationError)
    end
  end
end
