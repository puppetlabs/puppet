require 'spec_helper'
require 'puppet/settings/ttl_setting.rb'

describe Puppet::Settings::TTLSetting do

  { '5s' => 5, '10m' => 10 * 60, '12h' => 12 * 60 * 60, '1d' => 86400, '2y' => 2 * 365 * 86400 }.each do |ttl,expected|
    it "allows a #{ttl} TTL" do
      expect(ttl_setting.munge(ttl)).to eq(expected)
    end
  end

  it "disallows negative numeric TTL" do
    expect do
      ttl_setting.munge("-5s")
    end.to raise_error(Puppet::Settings::ValidationError)
  end

  it "allows an unlimited TTL" do
    expect(ttl_setting.munge("unlimited")).to eq(Puppet::Settings::TTLSetting::INFINITY)
  end

  it "allows a manual TTL" do
    expect(ttl_setting.munge("manual")).to eq(Puppet::Settings::TTLSetting::MANUAL)
  end

  def ttl_setting
    Puppet::Settings::TTLSetting.new(:settings => mock('settings'),
                                      :name => "testing",
                                      :desc => "description of testing"
                                    )
  end
end
