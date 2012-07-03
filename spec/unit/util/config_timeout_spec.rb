#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/util/config_timeout'



describe Puppet::Util::ConfigTimeout do
  # NOTE: in the future it might be a good idea to add an explicit "integer" type to
  #  the settings types, in which case this would no longer be necessary.


  class TestConfigTimeout
    include Puppet::Util::ConfigTimeout
  end

  let :instance do TestConfigTimeout.new end


  context "when the config setting is a String" do
    context "which contains an integer" do
      it "should convert the string to an integer" do
        Puppet[:configtimeout] = "12"
        instance.timeout_interval.should == 12
      end
    end

    context "which does not contain an integer do" do
      it "should raise an ArgumentError" do
        Puppet[:configtimeout] = "foo"
        expect {
          instance.timeout_interval
        }.to raise_error(ArgumentError)
      end
    end
  end

  context "when the config setting is an Integer" do
    it "should return the integer" do
      Puppet[:configtimeout] = 12
      instance.timeout_interval.should == 12
    end
  end

  context "when the config setting is some other type" do
    # test a random smattering of types
    [Hash.new, Array.new, Object.new].each do |obj|
      context "when the config setting is a #{obj.class}" do
        it "should raise an ArgumentError" do
          Puppet[:configtimeout] = Hash.new
          expect {
            instance.timeout_interval
          }.to raise_error(ArgumentError)
        end
      end
    end
  end
end
