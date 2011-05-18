#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/network_device/transport/telnet'

describe Puppet::Util::NetworkDevice::Transport::Telnet do

  before(:each) do
    @transport = Puppet::Util::NetworkDevice::Transport::Telnet.new()
  end

  it "should not handle login through the transport" do
    @transport.should_not be_handles_login
  end

  it "should connect to the given host and port" do
    Net::Telnet.expects(:new).with { |args| args["Host"] == "localhost" && args["Port"] == 23 }.returns stub_everything
    @transport.host = "localhost"
    @transport.port = 23

    @transport.connect
  end

  it "should connect and specify the default prompt" do
    @transport.default_prompt = "prompt"
    Net::Telnet.expects(:new).with { |args| args["Prompt"] == "prompt" }.returns stub_everything
    @transport.host = "localhost"
    @transport.port = 23

    @transport.connect
  end

  describe "when connected" do
    before(:each) do
      @telnet = stub_everything 'telnet'
      Net::Telnet.stubs(:new).returns(@telnet)
      @transport.connect
    end

    it "should send line to the telnet session" do
      @telnet.expects(:puts).with("line")
      @transport.send("line")
    end

    describe "when expecting output" do
      it "should waitfor output on the telnet session" do
        @telnet.expects(:waitfor).with(/regex/)
        @transport.expect(/regex/)
      end

      it "should return telnet session output" do
        @telnet.expects(:waitfor).returns("output")
        @transport.expect(/regex/).should == "output"
      end

      it "should yield telnet session output to the given block" do
        @telnet.expects(:waitfor).yields("output")
        @transport.expect(/regex/) { |out| out.should == "output" }
      end
    end
  end

  describe "when closing" do
    before(:each) do
      @telnet = stub_everything 'telnet'
      Net::Telnet.stubs(:new).returns(@telnet)
      @transport.connect
    end

    it "should close the telnet session" do
      @telnet.expects(:close)
      @transport.close
    end
  end
end
