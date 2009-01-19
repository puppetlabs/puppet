#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/agent/splayer'

describe Puppet::Agent::Splayer do
    it "should be able to splay" do
        Puppet::Agent::Splayer.new.should respond_to(:splay)
    end

    describe "when splaying" do
        before do
            @agent = Puppet::Agent::Splayer.new
            @agent.stubs(:name).returns "foo"

            Puppet.settings.stubs(:value).with(:splaylimit).returns "1800"
            Puppet.settings.stubs(:value).with(:splay).returns true
        end

        it "should sleep if it has not previously splayed" do
            Puppet.settings.expects(:value).with(:splay).returns true
            @agent.expects(:sleep)
            @agent.splay
        end
        
        it "should do nothing if it has already splayed" do
            @agent.expects(:sleep).once
            @agent.splay
            @agent.splay
        end

        it "should log if it is sleeping" do
            Puppet.settings.expects(:value).with(:splay).returns true
            @agent.stubs(:sleep)

            Puppet.expects(:info)

            @agent.splay
        end
    end
end
