require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/http_extra_headers_setting'

describe Puppet::Settings::HttpExtraHeadersSetting do
  subject { described_class.new(:settings => double('settings'), :desc => "test") }

  it "is of type :http_extra_headers" do
    expect(subject.type).to eq :http_extra_headers
  end

  describe "munging the value" do
    let(:final_value) { [['header1', 'foo'], ['header2', 'bar']] }

    describe "when given a string" do
      it "splits multiple values into an array" do
        expect(subject.munge("header1:foo,header2:bar")).to match_array(final_value)
      end

      it "strips whitespace between elements" do
        expect(subject.munge("header1:foo , header2:bar")).to match_array(final_value)
      end

      it "creates an array when one item is given" do
        expect(subject.munge("header1:foo")).to match_array([['header1', 'foo']])
      end
    end

    describe "when given an array of strings" do
      it "returns an array of arrays" do
        expect(subject.munge(['header1:foo', 'header2:bar'])).to match_array(final_value)
      end
    end

    describe "when given an array of arrays" do
      it "returns an array of arrays" do
        expect(subject.munge([['header1', 'foo'], ['header2', 'bar']])).to match_array(final_value)
      end
    end

    describe "when given a hash" do
      it "returns the hash" do
        expect(subject.munge({'header1' => 'foo', 'header2' => 'bar'})).to match_array(final_value)
      end
    end

    describe 'raises an error when' do

      # Ruby 2.3 reports the class of these objects as Fixnum, whereas later ruby versions report them as Integer
      it 'is given an unexpected object type' do
        expect {
          subject.munge(65)
          }.to raise_error(ArgumentError, /^Expected an Array, String, or Hash, got a (Integer|Fixnum)/)
      end

      it 'is given an array of unexpected object types' do
        expect {
          subject.munge([65, 82])
          }.to raise_error(ArgumentError, /^Expected an Array or String, got a (Integer|Fixnum)/)
      end
    end
  end
end
