#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/server'

# a fake server class, so we don't have to implement full autoloading etc. (or at least just yet) just to do testing
class TestServer < Puppet::Network::Server
  def start_web_server
  end
  
  def stop_web_server
  end
end

describe Puppet::Network::Server, "when initializing" do
  before do
    Puppet::Network::Server.stubs(:server_class_by_name).returns(TestServer)
  end
  
  it "should use the Puppet configurator to determine which HTTP server will be used to provide access to clients" do
    Puppet.expects(:[]).with(:servertype).returns(:suparserver)
    @server = Puppet::Network::Server.new
    @server.server_type.should == :suparserver
  end
  
  it "should fail to initialize if there is no HTTP server known to the Puppet configurator" do
    Puppet.expects(:[]).with(:servertype).returns(nil)
    Proc.new { Puppet::Network::Server.new }.should raise_error
  end
  
  it "should allow registering indirections" do
    @server = Puppet::Network::Server.new(:handlers => [ :foo, :bar, :baz])
    Proc.new { @server.unregister(:foo, :bar, :baz) }.should_not raise_error
  end
  
  it "should not be listening after initialization" do
    Puppet::Network::Server.new.should_not be_listening
  end
end

describe Puppet::Network::Server, "in general" do
  before do
    Puppet::Network::Server.stubs(:server_class_by_name).returns(TestServer)
    Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
    @server = Puppet::Network::Server.new
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

  it "should leave other indirections accessible to clients when turning off indirections" do
    @server.register(:foo, :bar)
    @server.unregister(:foo)
    Proc.new { @server.unregister(:bar)}.should_not raise_error
  end
  
  it "should allow specifying numerous indirections which are to be no longer accessible to clients" do
    @server.register(:foo, :bar)
    Proc.new { @server.unregister(:foo, :bar) }.should_not raise_error
  end
  
  it "should not allow turning off unknown indirection names" do
    @server.register(:foo, :bar)
    Proc.new { @server.unregister(:baz) }.should raise_error(ArgumentError)
  end
  
  it "should disable client access immediately when turning off indirections" do
    @server.register(:foo, :bar)
    @server.unregister(:foo)    
    Proc.new { @server.unregister(:foo) }.should raise_error(ArgumentError)
  end
  
  it "should allow turning off all indirections at once" do
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
    @server.server_type.should == :suparserver
  end

  it "should allow for multiple configurations, each handling different indirections" do
    @server2 = Puppet::Network::Server.new
    @server.register(:foo, :bar)
    @server2.register(:foo, :xyzzy)
    @server.unregister(:foo, :bar)
    @server2.unregister(:foo, :xyzzy)
    Proc.new { @server.unregister(:xyzzy) }.should raise_error(ArgumentError)
    Proc.new { @server2.unregister(:bar) }.should raise_error(ArgumentError)
  end  
end

describe Puppet::Network::Server, "when listening is turned off" do
  before do
    Puppet::Network::Server.stubs(:server_class_by_name).returns(TestServer)
    Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
    @server = Puppet::Network::Server.new
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
  
  it "should cause the HTTP server to listen when listening is turned on" do
    @server.expects(:start_web_server)
    @server.listen
  end
  
  it "should not route HTTP GET requests on indirector's name to indirector find for the specified HTTP server"
  it "should not route HTTP GET requests on indirector's plural name to indirector search for the specified HTTP server"
  it "should not route HTTP DELETE requests on indirector's name to indirector destroy for the specified HTTP server"
  it "should not route HTTP POST requests on indirector's name to indirector save for the specified HTTP server"

  # TODO: FIXME write integrations which fire up actual webrick / mongrel servers and are thus webrick / mongrel specific?]
end

describe Puppet::Network::Server, "when listening is turned on" do
  before do
    Puppet::Network::Server.stubs(:server_class_by_name).returns(TestServer)
    Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
    @server = Puppet::Network::Server.new
    @server.listen
  end
  
  it "should allow listening to be turned off" do
    Proc.new { @server.unlisten }.should_not raise_error
  end
  
  it "should not allow listening to be turned on" do
    Proc.new { @server.listen }.should raise_error(RuntimeError)
  end
  
  it "should indicate that listening is turned off" do
    @server.should be_listening
  end

  it "should cause the HTTP server to stop listening when listening is turned off" do
    @server.expects(:stop_web_server)
    @server.unlisten
  end
  
  it "should route HTTP GET requests on indirector's name to indirector find for the specified HTTP server"
  it "should route HTTP GET requests on indirector's plural name to indirector search for the specified HTTP server"
  it "should route HTTP DELETE requests on indirector's name to indirector destroy for the specified HTTP server"
  it "should route HTTP POST requests on indirector's name to indirector save for the specified HTTP server"

  # TODO: FIXME [ write integrations which fire up actual webrick / mongrel servers and are thus webrick / mongrel specific?]
end
