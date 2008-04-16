require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/server'
require 'socket'

describe Puppet::Network::Server do
  describe "when using webrick" do
    before :each do
      Puppet[:servertype] = 'webrick'
      @params = { :address => "127.0.0.1", :port => 34343, :handlers => [ :node ] }

      # LAK:NOTE (4/08) Stub the ssl support for now; we'll remove it once it's actually 
      # functional.
      Puppet::Network::HTTP::WEBrick.any_instance.stubs(:setup_ssl).returns({})
    end
    
    describe "before listening" do
      it "should not be reachable at the specified address and port" do
        lambda { TCPSocket.new('127.0.0.1', 34343) }.should raise_error
      end
    end
    
    describe "when listening" do
      it "should be reachable on the specified address and port" do
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))      
        @server.listen
        lambda { TCPSocket.new('127.0.0.1', 34343) }.should_not raise_error      
      end
            
      it "should not allow multiple servers to listen on the same address and port" do
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))      
        @server.listen
        @server2 = Puppet::Network::Server.new(@params.merge(:port => 34343))
        lambda { @server2.listen }.should raise_error
      end
      
      after :each do
        @server.unlisten if @server.listening?
      end
    end
    
    describe "after unlistening" do
      it "should not be reachable on the port and address assigned" do
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))      
        @server.listen
        @server.unlisten
        lambda { TCPSocket.new('127.0.0.1', 34343) }.should raise_error(Errno::ECONNREFUSED)        
      end
    end
  end
end
