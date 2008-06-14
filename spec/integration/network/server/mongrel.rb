#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/server'
require 'socket'

describe Puppet::Network::Server do
    describe "when using mongrel" do
        confine "Mongrel is not available" => Puppet.features.mongrel?
        
        before :each do
            Puppet[:servertype] = 'mongrel'
            @params = { :address => "127.0.0.1", :port => 34346, :handlers => [ :node ] }
            @server = Puppet::Network::Server.new(@params)            
        end

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
