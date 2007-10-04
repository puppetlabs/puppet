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
end

describe Puppet::Network::RESTServer, "when listening is not turned on" do
  it "should allow picking which technology to use to make indirections accessible to clients"
  it "should allow listening to be turned on"
  it "should not allow listening to be turned off"
  it "should not route HTTP GET requests on indirector's name to indirector find for the specified technology"
  it "should not route HTTP GET requests on indirector's plural name to indirector search for the specified technology"
  it "should not route HTTP DELETE requests on indirector's name to indirector destroy for the specified technology"
  it "should not route HTTP POST requests on indirector's name to indirector save for the specified technology"

  # TODO: FIXME write integrations which fire up actual webrick / mongrel servers and are thus webrick / mongrel specific?]
end

describe Puppet::Network::RESTServer, "when listening is turned on" do
  it "should not allow picking which technology to use to make indirections accessible to clients"
  it "should allow listening to be turned off"
  it "should not allow listening to be turned on"
  it "should route HTTP GET requests on indirector's name to indirector find for the specified technology"
  it "should route HTTP GET requests on indirector's plural name to indirector search for the specified technology"
  it "should route HTTP DELETE requests on indirector's name to indirector destroy for the specified technology"
  it "should route HTTP POST requests on indirector's name to indirector save for the specified technology"

  # TODO: FIXME [ write integrations which fire up actual webrick / mongrel servers and are thus webrick / mongrel specific?]
end
