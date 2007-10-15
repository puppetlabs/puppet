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
        @server = Puppet::Network::HTTP::WEBrick.new
        @listen_params = { :address => "127.0.0.1", :port => 31337, :handlers => { :foo => :bar }}
        Puppet.stubs(:start)
    end
    
    it "should fail if already listening" do
        @server.listen(@listen_params)
        Proc.new { @server.listen(@listen_params) }.should raise_error(RuntimeError)
    end
    
    it "should require at least one handler" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :handlers == k}) }.should raise_error(ArgumentError)
    end
    
    it "should require a listening address to be specified" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :address == k})}.should raise_error(ArgumentError)
    end
    
    it "should require a listening port to be specified" do
        Proc.new { @server.listen(@listen_params.delete_if {|k,v| :port == k})}.should raise_error(ArgumentError)        
    end

    it "should order a webrick server to start" do
        Puppet.expects(:start)
        @server.listen(@listen_params)
    end
    
    it "should tell webrick to listen on the specified address and port"
    
    it "should be listening" do
        @server.listen(@listen_params)
        @server.should be_listening
    end

    it "should instantiate a specific handler (webrick+rest, e.g.) for each handler, for each protocol being served (xmlrpc, rest, etc.)"
    it "should mount handlers on a webrick path"
end

describe Puppet::Network::HTTP::WEBrick, "when turning off listening" do
    before do
        @server = Puppet::Network::HTTP::WEBrick.new        
        @server.stubs(:shutdown)
        @listen_params = { :address => "127.0.0.1", :port => 31337, :handlers => { :foo => :bar }}
        Puppet.stubs(:start).returns(true)
    end
    
    it "should fail unless listening" do
        Proc.new { @server.unlisten }.should raise_error(RuntimeError)
    end
    
    it "should order webrick server to stop" do
        @server.should respond_to(:shutdown)
        @server.expects(:shutdown)
        @server.listen(@listen_params)
        @server.unlisten
    end
    
    it "should no longer be listening" do
        @server.listen(@listen_params)
        @server.unlisten
        @server.should_not be_listening
    end
end
