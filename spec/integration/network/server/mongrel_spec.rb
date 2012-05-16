#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/network/server'
require 'net/http'

describe Puppet::Network::Server, :'fails_on_ruby_1.9.2' => true do
  describe "when using mongrel", :if => Puppet.features.mongrel? do

    # This reduces the odds of conflicting port numbers between concurrent runs
    # of the suite on the same machine dramatically.
    def port
      20001 + ($$ % 40000)
    end

    before :each do
      Puppet[:servertype] = 'mongrel'
      Puppet[:server] = '127.0.0.1'
      @params = { :port => port, :handlers => [ :node ] }
      @server = Puppet::Network::Server.new(@params)
    end

    after :each do
      @server.unlisten if @server.listening?
    end

    describe "before listening" do
      it "should not be reachable at the specified address and port" do
        lambda { Net::HTTP.get('127.0.0.1', '/', port) }.
          should raise_error(Errno::ECONNREFUSED)
      end
    end

    describe "when listening" do
      it "should be reachable on the specified address and port" do
        @server.listen
        expect { Net::HTTP.get('127.0.0.1', '/', port) }.should_not raise_error
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
        expect { Net::HTTP.get('127.0.0.1', '/', port) }.
          should raise_error Errno::ECONNREFUSED
      end
    end
  end
end
