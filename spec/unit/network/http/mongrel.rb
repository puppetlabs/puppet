#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-15.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::Mongrel, "after initializing" do
    it "should not be listening" do
        Puppet::Network::HTTP::Mongrel.new.should_not be_listening
    end
end

describe Puppet::Network::HTTP::Mongrel, "when turning on listening" do
    before do
        @server = Puppet::Network::HTTP::Mongrel.new
        @mock_mongrel = mock('mongrel')
        @mock_mongrel.stubs(:run)
        Mongrel::HttpServer.stubs(:new).returns(@mock_mongrel)
        @listen_params = { :address => "127.0.0.1", :port => 31337, :handlers => [ :node, :configuration ], :protocols => [ :rest, :xmlrpc ] }
    end
    
    it "should fail if already listening" do
        @server.listen(@listen_params)
        Proc.new { @server.listen(@listen_params) }.should raise_error(RuntimeError)
    end
    
    it "should require at least one handler" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :handlers == k}) }.should raise_error(ArgumentError)
    end
    
    it "should require at least one protocol" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :protocols == k}) }.should raise_error(ArgumentError)
    end
    
    it "should require a listening address to be specified" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :address == k})}.should raise_error(ArgumentError)
    end
    
    it "should require a listening port to be specified" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :port == k})}.should raise_error(ArgumentError)
    end
    
    it "should order a mongrel server to start" do
        @mock_mongrel.expects(:run)
        @server.listen(@listen_params)
    end
    
    it "should tell mongrel to listen on the specified address and port" do
        Mongrel::HttpServer.expects(:new).with("127.0.0.1", 31337).returns(@mock_mongrel)
        @server.listen(@listen_params)
    end
    
    it "should be listening" do
        mock_mongrel = mock('mongrel httpserver')
        mock_mongrel.expects(:run)
        Mongrel::HttpServer.expects(:new).returns(mock_mongrel)
        @server.listen(@listen_params)
        @server.should be_listening
    end

    it "should instantiate a specific handler (mongrel+rest, e.g.) for each named handler, for each named protocol)" do
        @listen_params[:handlers].each do |handler|
            @listen_params[:protocols].each do |protocol|
                mock_handler = mock("handler instance for [#{protocol}]+[#{handler}]")
                mock_handler_class = mock("handler class for [#{protocol}]+[#{handler}]")
                mock_handler_class.expects(:new).returns(mock_handler)
                @server.expects(:class_for_protocol_handler).with(protocol, handler).returns(mock_handler_class)
            end
        end
        @server.listen(@listen_params)
    end
    
    it "should mount each handler on a mongrel path" do
        pending "a moment of clarity"
        @listen_params[:handlers].each do |handler|
            @listen_params[:protocols].each do |protocol|
                mock_handler = mock("handler instance for [#{protocol}]+[#{handler}]")
                mock_handler_class = mock("handler class for [#{protocol}]+[#{handler}]")
                mock_handler_class.stubs(:new).returns(mock_handler)
                @server.stubs(:class_for_protocol_handler).with(protocol, handler).returns(mock_handler_class)
                # TODO / FIXME : HERE -- need to begin resolving the model behind the indirection
            end
        end
        @server.listen(@listen_params)        
    end
end

describe Puppet::Network::HTTP::Mongrel, "when turning off listening" do
    before do
        @mock_mongrel = mock('mongrel httpserver')
        @mock_mongrel.stubs(:run)
        Mongrel::HttpServer.stubs(:new).returns(@mock_mongrel)
        @server = Puppet::Network::HTTP::Mongrel.new        
        @listen_params = { :address => "127.0.0.1", :port => 31337, :handlers => [ :node, :configuration ], :protocols => [ :rest, :xmlrpc ] }
    end
    
    it "should fail unless listening" do
        Proc.new { @server.unlisten }.should raise_error(RuntimeError)
    end
    
    it "should order mongrel server to stop" do
        @server.listen(@listen_params)
        @mock_mongrel.expects(:graceful_shutdown)
        @server.unlisten
    end
    
    it "should not be listening" do
        @server.listen(@listen_params)
        @mock_mongrel.stubs(:graceful_shutdown)
        @server.unlisten
        @server.should_not be_listening
    end
end
