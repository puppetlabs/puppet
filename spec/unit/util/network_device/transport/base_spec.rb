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
      expect(@transport).to receive(:send).with("line")
      @transport.command("line")
    end

    it "should expect an output matching the given prompt" do
      expect(@transport).to receive(:expect).with(/prompt/)
      @transport.command("line", :prompt => /prompt/)
    end

    it "should expect an output matching the default prompt" do
      @transport.default_prompt = /defprompt/
      expect(@transport).to receive(:expect).with(/defprompt/)
      @transport.command("line")
    end

    it "should yield telnet output to the given block" do
      expect(@transport).to receive(:expect).and_yield("output")
      @transport.command("line") { |out| expect(out).to eq("output") }
    end

    it "should return telnet output to the caller" do
      expect(@transport).to receive(:expect).and_return("output")
      expect(@transport.command("line")).to eq("output")
    end
  end
end
