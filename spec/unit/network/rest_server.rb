#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_server'

describe Puppet::Network::RESTServer, "in general" do
  before do
    Puppet::Network::RESTServer.reset
  end
  
  it "should allow registering an indirection for client access by specifying its indirection name" do
    Proc.new { Puppet::Network::RESTServer.register(:foo) }.should_not raise_error
  end
  
  it "should require at least one indirection name when registering indirections for client access" do
    Proc.new { Puppet::Network::RESTServer.register }.should raise_error(ArgumentError)
  end
  
  it "should allow for numerous indirections to be registered at once for client access" do
    Proc.new { Puppet::Network::RESTServer.register(:foo, :bar, :baz) }.should_not raise_error
  end

  it "should allow the use of indirection names to specify which indirections are to be no longer accessible to clients" do
    Puppet::Network::RESTServer.register(:foo)
    Proc.new { Puppet::Network::RESTServer.unregister(:foo) }.should_not raise_error    
  end

  it "should leave other indirections accessible to clients when turning off other indirections" do
    Puppet::Network::RESTServer.register(:foo, :bar)
    Puppet::Network::RESTServer.unregister(:foo)
    Proc.new { Puppet::Network::RESTServer.unregister(:bar)}.should_not raise_error
  end
  
  it "should allow specifying numerous indirections which are to be no longer accessible to clients" do
    Puppet::Network::RESTServer.register(:foo, :bar)
    Proc.new { Puppet::Network::RESTServer.unregister(:foo, :bar) }.should_not raise_error
  end
  
  it "should not allow for unregistering unknown indirection names" do
    Puppet::Network::RESTServer.register(:foo, :bar)
    Proc.new { Puppet::Network::RESTServer.unregister(:baz) }.should raise_error(ArgumentError)
  end
  
  it "should disable client access immediately" do
    Puppet::Network::RESTServer.register(:foo, :bar)
    Puppet::Network::RESTServer.unregister(:foo)    
    Proc.new { Puppet::Network::RESTServer.unregister(:foo) }.should raise_error(ArgumentError)
  end
  
  it "should allow clearing out the list of all indirection accessible to clients" do
    Puppet::Network::RESTServer.register(:foo, :bar)
    Puppet::Network::RESTServer.reset
    [ :foo, :bar, :baz].each do |indirection|
      Proc.new { Puppet::Network::RESTServer.unregister(indirection) }.should raise_error(ArgumentError)
    end
  end
  
  it "should use the normal means of turning off indirections accessible to clients when clearing all indirections" do
    Puppet::Network::RESTServer.register(:foo, :bar, :baz)
    Puppet::Network::RESTServer.expects(:unregister).with do |args|
      args.include?(:foo) && args.include?(:bar) && args.include?(:baz)
    end
    Puppet::Network::RESTServer.reset
  end
  
  it "should provide a means of determining whether it is providing access to clients" do
    Puppet::Network::RESTServer.should respond_to(:listening?)
  end
end

describe Puppet::Network::RESTServer, "when listening is not turned on" do
  before do
    Puppet::Network::RESTServer.unlisten if Puppet::Network::RESTServer.listening?
  end
  
  it "should allow listening to be turned on" do
    Proc.new { Puppet::Network::RESTServer.listen }.should_not raise_error
  end
  
  it "should not allow listening to be turned off" do
    Proc.new { Puppet::Network::RESTServer.unlisten }.should raise_error(RuntimeError)
  end
  
  it "should indicate that it is not listening" do
    Puppet::Network::RESTServer.should_not be_listening
  end
  
  it "should allow picking which technology to use to make indirections accessible to clients"
  it "should not route HTTP GET requests on indirector's name to indirector find for the specified technology"
  it "should not route HTTP GET requests on indirector's plural name to indirector search for the specified technology"
  it "should not route HTTP DELETE requests on indirector's name to indirector destroy for the specified technology"
  it "should not route HTTP POST requests on indirector's name to indirector save for the specified technology"

  # TODO: FIXME write integrations which fire up actual webrick / mongrel servers and are thus webrick / mongrel specific?]
end

describe Puppet::Network::RESTServer, "when listening is turned on" do
  before do
    Puppet::Network::RESTServer.listen unless Puppet::Network::RESTServer.listening?
  end
  
  it "should allow listening to be turned off" do
    Proc.new { Puppet::Network::RESTServer.unlisten }.should_not raise_error
  end
  
  it "should not allow listening to be turned on" do
    Proc.new { Puppet::Network::RESTServer.listen }.should raise_error(RuntimeError)
  end
  
  it "should indicate that it is  listening" do
    Puppet::Network::RESTServer.should be_listening
  end
  
  it "should not allow picking which technology to use to make indirections accessible to clients"
  it "should route HTTP GET requests on indirector's name to indirector find for the specified technology"
  it "should route HTTP GET requests on indirector's plural name to indirector search for the specified technology"
  it "should route HTTP DELETE requests on indirector's name to indirector destroy for the specified technology"
  it "should route HTTP POST requests on indirector's name to indirector save for the specified technology"

  # TODO: FIXME [ write integrations which fire up actual webrick / mongrel servers and are thus webrick / mongrel specific?]
end


# TODO: FIXME == should be able to have multiple servers running on different technologies, or with different configurations -- this will force an instance model
