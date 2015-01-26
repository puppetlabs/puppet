#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/priority_setting'
require 'puppet/util/platform'

describe Puppet::Settings::PrioritySetting do
  let(:setting) { described_class.new(:settings => mock('settings'), :desc => "test") }

  it "is of type :priority" do
    expect(setting.type).to eq(:priority)
  end

  describe "when munging the setting" do
    it "passes nil through" do
      expect(setting.munge(nil)).to be_nil
    end

    it "returns the same value if given an integer" do
      expect(setting.munge(5)).to eq(5)
    end

    it "returns an integer if given a decimal string" do
      expect(setting.munge('12')).to eq(12)
    end

    it "returns a negative integer if given a negative integer string" do
      expect(setting.munge('-5')).to eq(-5)
    end

    it "fails if given anything else" do
      [ 'foo', 'realtime', true, 8.3, [] ].each do |value|
        expect {
          setting.munge(value)
        }.to raise_error(Puppet::Settings::ValidationError)
      end
    end

    describe "on a Unix-like platform it", :unless => Puppet::Util::Platform.windows? do
      it "parses high, normal, low, and idle priorities" do
        {
          'high'   => -10,
          'normal' => 0,
          'low'    => 10,
          'idle'   => 19
        }.each do |value, converted_value|
          expect(setting.munge(value)).to eq(converted_value)
        end
      end
    end

    describe "on a Windows-like platform it", :if => Puppet::Util::Platform.windows? do
      it "parses high, normal, low, and idle priorities" do
        {
          'high'   => Puppet::Util::Windows::Process::HIGH_PRIORITY_CLASS,
          'normal' => Puppet::Util::Windows::Process::NORMAL_PRIORITY_CLASS,
          'low'    => Puppet::Util::Windows::Process::BELOW_NORMAL_PRIORITY_CLASS,
          'idle'   => Puppet::Util::Windows::Process::IDLE_PRIORITY_CLASS
        }.each do |value, converted_value|
          expect(setting.munge(value)).to eq(converted_value)
        end
      end
    end
  end
end
