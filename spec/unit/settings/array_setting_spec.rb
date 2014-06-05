require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/array_setting'

describe Puppet::Settings::ArraySetting do
  subject { described_class.new(:settings => stub('settings'), :desc => "test") }

  it "is of type :array" do
    expect(subject.type).to eq :array
  end

  describe "munging the value" do
    describe "when given a string" do
      it "splits multiple values into an array" do
        expect(subject.munge("foo,bar")).to eq %w[foo bar]
      end
      it "strips whitespace between elements" do
        expect(subject.munge("foo , bar")).to eq %w[foo bar]
      end

      it "creates an array when one item is given" do
        expect(subject.munge("foo")).to eq %w[foo]
      end
    end

    describe "when given an array" do
      it "returns the array" do
        expect(subject.munge(%w[foo])).to eq %w[foo]
      end
    end

    it "raises an error when given an unexpected object type" do
        expect {
          subject.munge({:foo => 'bar'})
        }.to raise_error(ArgumentError, "Expected an Array or String, got a Hash")
    end
  end
end
