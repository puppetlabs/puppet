#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/network_device/transport/base'

describe Puppet::Util::NetworkDevice::Transport::Base do
  class TestTransport < Puppet::Util::NetworkDevice::Transport::Base
  end

  before(:each) do
    @transport = TestTransport.new
  end

  describe "when sending commands" do
    it "should send the command to the telnet session" do
      @transport.expects(:send).with("line")
      @transport.command("line")
    end

    it "should expect an output matching the given prompt" do
      @transport.expects(:expect).with(/prompt/)
      @transport.command("line", :prompt => /prompt/)
    end

    it "should expect an output matching the default prompt" do
      @transport.default_prompt = /defprompt/
      @transport.expects(:expect).with(/defprompt/)
      @transport.command("line")
    end

    it "should yield telnet output to the given block" do
      @transport.expects(:expect).yields("output")
      @transport.command("line") { |out| expect(out).to eq("output") }
    end

    it "should return telnet output to the caller" do
      @transport.expects(:expect).returns("output")
      expect(@transport.command("line")).to eq("output")
    end
  end
end
