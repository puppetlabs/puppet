require 'spec_helper'

require 'puppet/settings'

describe Puppet::Settings::EnumSetting do
  it "allows a configured value" do
    setting = enum_setting_allowing("allowed")

    expect(setting.munge("allowed")).to eq("allowed")
  end

  it "disallows a value that is not configured" do
    setting = enum_setting_allowing("allowed", "also allowed")

    expect do
      setting.munge("disallowed")
    end.to raise_error(Puppet::Settings::ValidationError,
                       "Invalid value 'disallowed' for parameter testing. Allowed values are 'allowed', 'also allowed'")
  end

  def enum_setting_allowing(*values)
    Puppet::Settings::EnumSetting.new(:settings => mock('settings'),
                                      :name => "testing",
                                      :desc => "description of testing",
                                      :values => values)
  end
end
