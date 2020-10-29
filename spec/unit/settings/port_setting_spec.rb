require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/port_setting'

describe Puppet::Settings::PortSetting do
  let(:setting) { described_class.new(:settings => double('settings'), :desc => "test") }

  it "is of type :port" do
    expect(setting.type).to eq(:port)
  end

  describe "when munging the setting" do
    it "returns the same value if given a valid port as integer" do
      expect(setting.munge(5)).to eq(5)
    end

    it "returns an integer if given valid port as string" do
      expect(setting.munge('12')).to eq(12)
    end

    it "raises if given a negative port number" do
      expect { setting.munge('-5') }.to raise_error(Puppet::Settings::ValidationError)
    end

    it "raises if the port number is too high" do
      expect { setting.munge(65536) }.to raise_error(Puppet::Settings::ValidationError)
    end

  end
end
