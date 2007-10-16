#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-15.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::WEBrick, "after initializing" do
    it "should not be listening" do
        Puppet::Network::HTTP::WEBrick.new.should_not be_listening
    end
end

describe Puppet::Network::HTTP::WEBrick, "when turning on listening" do
    before do
        @mock_webrick = mock('webrick')
        [:mount, :start, :shutdown].each {|meth| @mock_webrick.stubs(meth)}        
        WEBrick::HTTPServer.stubs(:new).returns(@mock_webrick)
        @server = Puppet::Network::HTTP::WEBrick.new
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

    it "should order a webrick server to start" do
        @mock_webrick.expects(:start)
        @server.listen(@listen_params)
    end
    
    it "should tell webrick to listen on the specified address and port" do
        WEBrick::HTTPServer.expects(:new).with {|args|
            args[:Port] == 31337 and args[:BindAddress] == "127.0.0.1"
        }.returns(@mock_webrick)
        @server.listen(@listen_params)
    end
    
    it "should be listening" do
        @server.listen(@listen_params)
        @server.should be_listening
    end
    
    it "should instantiate a handler for each protocol+handler pair to configure web server routing" do
        @listen_params[:protocols].each do |protocol|
            mock_handler = mock("handler instance for [#{protocol}]")
            mock_handler_class = mock("handler class for [#{protocol}]")
            @listen_params[:handlers].each do |handler|
                mock_handler_class.expects(:new).with {|args| 
                    args[:server] == @mock_webrick and args[:handler] == handler
                }.returns(mock_handler)
            end
            @server.expects(:class_for_protocol).with(protocol).at_least_once.returns(mock_handler_class)
        end
        @server.listen(@listen_params)        
    end

    it "should use a WEBrick + REST class to configure WEBrick when REST services are requested" do
        Puppet::Network::HTTP::WEBrickREST.expects(:new).at_least_once
        @server.listen(@listen_params.merge(:protocols => [:rest]))
    end
    
    it "should use a WEBrick + XMLRPC class to configure WEBrick when XMLRPC services are requested" do
        Puppet::Network::HTTP::WEBrickXMLRPC.expects(:new).at_least_once
        @server.listen(@listen_params.merge(:protocols => [:xmlrpc]))        
    end
    
    it "should fail if services from an unknown protocol are requested" do
        Proc.new { @server.listen(@listen_params.merge(:protocols => [ :foo ]))}.should raise_error(ArgumentError)
    end
end

describe Puppet::Network::HTTP::WEBrick, "when turning off listening" do
    before do
        @mock_webrick = mock('webrick')
        [:mount, :start, :shutdown].each {|meth| @mock_webrick.stubs(meth)}
        WEBrick::HTTPServer.stubs(:new).returns(@mock_webrick)
        @server = Puppet::Network::HTTP::WEBrick.new        
        @listen_params = { :address => "127.0.0.1", :port => 31337, :handlers => [ :node, :configuration ], :protocols => [ :rest, :xmlrpc ] }
    end
    
    it "should fail unless listening" do
        Proc.new { @server.unlisten }.should raise_error(RuntimeError)
    end
    
    it "should order webrick server to stop" do
        @mock_webrick.expects(:shutdown)
        @server.listen(@listen_params)
        @server.unlisten
    end
    
    it "should no longer be listening" do
        @server.listen(@listen_params)
        @server.unlisten
        @server.should_not be_listening
    end
end
