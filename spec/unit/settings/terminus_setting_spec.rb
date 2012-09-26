#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Settings::TerminusSetting do
  let(:setting) { described_class.new(:settings => mock('settings'), :desc => "test") }

  describe "#munge" do
    it "converts strings to symbols" do
      setting.munge("string").should == :string
    end

    it "converts '' to nil" do
      setting.munge('').should be_nil
    end

    it "preserves symbols" do
      setting.munge(:symbol).should == :symbol
    end

    it "preserves nil" do
      setting.munge(nil).should be_nil
    end

    it "does not allow unknown types through" do
      expect { setting.munge(["not a terminus type"]) }.to raise_error Puppet::Settings::ValidationError
    end
  end
end
