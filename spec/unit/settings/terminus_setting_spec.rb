#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Settings::TerminusSetting do
  let(:setting) { described_class.new(:settings => mock('settings'), :desc => "test") }

  describe "#munge" do
    it "converts strings to symbols" do
      expect(setting.munge("string")).to eq(:string)
    end

    it "converts '' to nil" do
      expect(setting.munge('')).to be_nil
    end

    it "preserves symbols" do
      expect(setting.munge(:symbol)).to eq(:symbol)
    end

    it "preserves nil" do
      expect(setting.munge(nil)).to be_nil
    end

    it "does not allow unknown types through" do
      expect { setting.munge(["not a terminus type"]) }.to raise_error Puppet::Settings::ValidationError
    end
  end
end
