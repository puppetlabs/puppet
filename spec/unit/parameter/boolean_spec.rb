#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet'
require 'puppet/parameter/boolean'

describe Puppet::Parameter::Boolean do
  let (:resource) { mock('resource') }
  describe "after initvars" do
    before { described_class.initvars }
    it "should have the correct value_collection" do
      expect(described_class.value_collection.values.sort).to eq(
          [:true, :false, :yes, :no].sort
      )
    end
  end

  describe "instances" do
    subject { described_class.new(:resource => resource) }

    [ true, :true, 'true', :yes, 'yes', 'TrUe', 'yEs' ].each do |arg|
      it "should munge #{arg.inspect} as true" do
        expect(subject.munge(arg)).to eq(true)
      end
    end
    [ false, :false, 'false', :no, 'no', 'FaLSE', 'nO' ].each do |arg|
      it "should munge #{arg.inspect} as false" do
        expect(subject.munge(arg)).to eq(false)
      end
    end
    [ nil, :undef, 'undef', '0', 0, '1', 1, 9284 ].each do |arg|
      it "should fail to munge #{arg.inspect}" do
        expect { subject.munge(arg) }.to raise_error Puppet::Error
      end
    end
  end
end
