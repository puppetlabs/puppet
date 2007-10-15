#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-15.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::WEBRick, "when turning on listening" do
    before do
        @server = Puppet::Network::HTTP::WEBRick.new
    end
    
    it "should fail if already listening" do
        Puppet.stubs(:start)
        @server.listen(:foo => :bar)
        Proc.new { @server.listen(:foo => :bar) }.should raise_error(RuntimeError)
    end
    
    it "should require at least one handler" do
        Proc.new { @server.listen }.should raise_error(ArgumentError)
    end
    
    it "should order a webrick server to start" do
        Puppet.expects(:start)
        @server.listen(:foo => :bar)
    end

    it "should instantiate a specific handler (webrick+rest, e.g.) for each handler, for each protocol being served (xmlrpc, rest, etc.)"
    it "should mount handlers on a webrick path"

    it "should be able to specify the address on which webrick will listen"
    it "should be able to specify the port on which webrick will listen"
end

describe Puppet::Network::HTTP::WEBRick, "when turning off listening" do
    before do
        @server = Puppet::Network::HTTP::WEBRick.new        
    end
    
    it "should fail unless listening" do
        Proc.new { @server.unlisten }.should raise_error(RuntimeError)
    end
    
    it "should order webrick server to stop" do
        Puppet.stubs(:start).returns(true)
        @server.should respond_to(:shutdown)
        @server.expects(:shutdown)
        @server.listen(:foo => :bar)
        @server.unlisten
    end
end
