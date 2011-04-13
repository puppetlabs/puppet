#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Util::Warnings do
  before(:all) do
    @msg1 = "booness"
    @msg2 = "more booness"
  end

  {:notice => "notice_once", :warning => "warnonce"}.each do |log, method|
    describe "when registring '#{log}' messages" do
      it "should always return nil" do
        Puppet::Util::Warnings.send(method, @msg1).should be(nil)
      end

      it "should issue a warning" do
        Puppet.expects(log).with(@msg1)
        Puppet::Util::Warnings.send(method, @msg1)
      end

      it "should issue a warning exactly once per unique message" do
        Puppet.expects(log).with(@msg1).once
        Puppet::Util::Warnings.send(method, @msg1)
        Puppet::Util::Warnings.send(method, @msg1)
      end

      it "should issue multiple warnings for multiple unique messages" do
        Puppet.expects(log).times(2)
        Puppet::Util::Warnings.send(method, @msg1)
        Puppet::Util::Warnings.send(method, @msg2)
      end
    end
  end

  after(:each) do
    Puppet::Util::Warnings.clear_warnings
  end
end
