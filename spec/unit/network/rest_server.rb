#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_server'

describe Puppet::Network::RESTServer, "when initializing" do
  it "should require specifying which HTTP server will be used to provide access to clients" do
    Proc.new { Puppet::Network::RESTServer.new }.should raise_error(ArgumentError)
  end
end

describe Puppet::Network::RESTServer, "in general" do
  before do
    @server = Puppet::Network::RESTServer.new(:server => :mongrel)
  end
  
  it "should allow registering an indirection for client access by specifying its indirection name" do
    Proc.new { @server.register(:foo) }.should_not raise_error
  end
  
  it "should require at least one indirection name when registering indirections for client access" do
    Proc.new { @server.register }.should raise_error(ArgumentError)
  end
  
  it "should allow for numerous indirections to be registered at once for client access" do
    Proc.new { @server.register(:foo, :bar, :baz) }.should_not raise_error
  end

  it "should allow the use of indirection names to specify which indirections are to be no longer accessible to clients" do
    @server.register(:foo)
    Proc.new { @server.unregister(:foo) }.should_not raise_error    
  end

  it "should leave other indirections accessible to clients when turning off other indirections" do
    @server.register(:foo, :bar)
    @server.unregister(:foo)
    Proc.new { @server.unregister(:bar)}.should_not raise_error
  end
  
  it "should allow specifying numerous indirections which are to be no longer accessible to clients" do
    @server.register(:foo, :bar)
    Proc.new { @server.unregister(:foo, :bar) }.should_not raise_error
  end
  
  it "should not allow for unregistering unknown indirection names" do
    @server.register(:foo, :bar)
    Proc.new { @server.unregister(:baz) }.should raise_error(ArgumentError)
  end
  
  it "should disable client access immediately" do
    @server.register(:foo, :bar)
    @server.unregister(:foo)    
    Proc.new { @server.unregister(:foo) }.should raise_error(ArgumentError)
  end
  
  it "should allow clearing out the list of all indirection accessible to clients" do
    @server.register(:foo, :bar)
    @server.unregister
    [ :foo, :bar, :baz].each do |indirection|
      Proc.new { @server.unregister(indirection) }.should raise_error(ArgumentError)
    end
  end
  
  it "should provide a means of determining whether it is listening" do
    @server.should respond_to(:listening?)
  end
  
  it "should provide a means of determining which HTTP server will be used to provide access to clients" do
    @server.server.should == :mongrel
  end

  it "should allow for multiple configurations, each allowing different indirections for client access" do
    @server2 = Puppet::Network::RESTServer.new(:server => :webrick)
    @server.register(:foo, :bar)
    @server2.register(:foo, :xyzzy)
    @server.unregister(:foo, :bar)
    @server2.unregister(:foo, :xyzzy)
    Proc.new { @server.unregister(:xyzzy) }.should raise_error(ArgumentError)
    Proc.new { @server2.unregister(:bar)}.should raise_error(ArgumentError)
  end  
end

describe Puppet::Network::RESTServer, "when listening is not turned on" do
  before do
    @server = Puppet::Network::RESTServer.new(:server => :mongrel)
  end
  
  it "should allow listening to be turned on" do
    Proc.new { @server.listen }.should_not raise_error
  end
  
  it "should not allow listening to be turned off" do
    Proc.new { @server.unlisten }.should raise_error(RuntimeError)
  end
  
  it "should indicate that it is not listening" do
    @server.should_not be_listening
  end
  
  it "should not route HTTP GET requests on indirector's name to indirector find for the specified HTTP server"
  it "should not route HTTP GET requests on indirector's plural name to indirector search for the specified HTTP server"
  it "should not route HTTP DELETE requests on indirector's name to indirector destroy for the specified HTTP server"
  it "should not route HTTP POST requests on indirector's name to indirector save for the specified HTTP server"

  # TODO: FIXME write integrations which fire up actual webrick / mongrel servers and are thus webrick / mongrel specific?]
end

describe Puppet::Network::RESTServer, "when listening is turned on" do
  before do
    @server = Puppet::Network::RESTServer.new(:server => :mongrel)
    @server.listen
  end
  
  it "should allow listening to be turned off" do
    Proc.new { @server.unlisten }.should_not raise_error
  end
  
  it "should not allow listening to be turned on" do
    Proc.new { @server.listen }.should raise_error(RuntimeError)
  end
  
  it "should indicate that it is  listening" do
    @server.should be_listening
  end
  
  it "should route HTTP GET requests on indirector's name to indirector find for the specified HTTP server"
  it "should route HTTP GET requests on indirector's plural name to indirector search for the specified HTTP server"
  it "should route HTTP DELETE requests on indirector's name to indirector destroy for the specified HTTP server"
  it "should route HTTP POST requests on indirector's name to indirector save for the specified HTTP server"

  # TODO: FIXME [ write integrations which fire up actual webrick / mongrel servers and are thus webrick / mongrel specific?]
end
