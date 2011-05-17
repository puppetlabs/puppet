#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/network/server'
require 'socket'

describe Puppet::Network::Server, :'fails_on_ruby_1.9.2' => true do
  describe "when using mongrel", :if => Puppet.features.mongrel? do

    before :each do
      Puppet[:servertype] = 'mongrel'
      Puppet[:server] = '127.0.0.1'
      @params = { :port => 34346, :handlers => [ :node ] }
      @server = Puppet::Network::Server.new(@params)
    end

    after { Puppet.settings.clear }

    describe "before listening" do
      it "should not be reachable at the specified address and port" do
        lambda { TCPSocket.new('127.0.0.1', 34346) }.should raise_error(Errno::ECONNREFUSED)
      end
    end

    describe "when listening" do
      it "should be reachable on the specified address and port" do
        @server.listen
        lambda { TCPSocket.new('127.0.0.1', 34346) }.should_not raise_error
      end

      it "should default to '127.0.0.1' as its bind address" do
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))
        @server.stubs(:unlisten) # we're breaking listening internally, so we have to keep it from unlistening
        @server.send(:http_server).expects(:listen).with { |args| args[:address] == "127.0.0.1" }
        @server.listen
      end

      it "should use any specified bind address" do
        Puppet[:bindaddress] = "0.0.0.0"
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))
        @server.stubs(:unlisten) # we're breaking listening internally, so we have to keep it from unlistening
        @server.send(:http_server).expects(:listen).with { |args| args[:address] == "0.0.0.0" }
        @server.listen
      end

      it "should not allow multiple servers to listen on the same address and port" do
        @server.listen
        @server2 = Puppet::Network::Server.new(@params)
        lambda { @server2.listen }.should raise_error
      end
    end

    describe "after unlistening" do
      it "should not be reachable on the port and address assigned" do
        @server.listen
        @server.unlisten
        lambda { TCPSocket.new('127.0.0.1', 34346) }.should raise_error(Errno::ECONNREFUSED)
      end
    end

    after :each do
      @server.unlisten if @server.listening?
    end
  end
end
