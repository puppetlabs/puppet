#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Util::Warnings, " when registering a warning message" do
    before(:all) do
        @msg1 = "booness"
        @msg2 = "more booness"
    end

    it "should always return nil" do
        Puppet::Util::Warnings.warnonce(@msg1).should be(nil)
    end

    it "should issue a warning" do
        Puppet.expects(:warning).with(@msg1)
        Puppet::Util::Warnings.warnonce(@msg1)
    end

    it "should issue a warning exactly once per unique message" do
        Puppet.expects(:warning).with(@msg1).once
        Puppet::Util::Warnings.warnonce(@msg1)
        Puppet::Util::Warnings.warnonce(@msg1)
    end

    it "should issue multiple warnings for multiple unique messages" do
        Puppet.expects(:warning).times(2)
        Puppet::Util::Warnings.warnonce(@msg1)
        Puppet::Util::Warnings.warnonce(@msg2)
    end

    after(:each) do
        Puppet::Util::Warnings.clear_warnings()
    end
end
