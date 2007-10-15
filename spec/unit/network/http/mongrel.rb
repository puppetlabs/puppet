#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-15.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::Mongrel, "when turning on listening" do
    before do
        @server = Puppet::Network::HTTP::Mongrel.new
    end
    
    it "should fail if already listening" do
        @server.listen(:foo => :bar)
        Proc.new { @server.listen(:foo => :bar) }.should raise_error(RuntimeError)
    end
    
    it "should require at least one handler" do
        Proc.new { @server.listen }.should raise_error(ArgumentError)
    end
    
    it "should order a mongrel server to start" do
        mock_mongrel = mock('mongrel httpserver')
        mock_mongrel.expects(:run)
        Mongrel::HttpServer.expects(:new).returns(mock_mongrel)
        @server.listen(:foo => :bar)
    end

    it "should instantiate a specific handler (mongrel+rest, e.g.) for each handler, for each protocol being served (xmlrpc, rest, etc.)"
    it "should mount handlers on a mongrel path"    
    it "should be able to specify the address on which mongrel will listen"
    it "should be able to specify the port on which mongrel will listen"
end

describe Puppet::Network::HTTP::WEBRick, "when turning off listening" do
    before do
        @mock_mongrel = mock('mongrel httpserver')
        @mock_mongrel.stubs(:run)
        Mongrel::HttpServer.stubs(:new).returns(@mock_mongrel)
        @server = Puppet::Network::HTTP::Mongrel.new        
    end
    
    it "should fail unless listening" do
        Proc.new { @server.unlisten }.should raise_error(RuntimeError)
    end
    
    it "should order mongrel server to stop" do
        @server.listen(:foo => :bar)
        @mock_mongrel.expects(:graceful_shutdown)
        @server.unlisten
    end
end
