#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_server'

describe Puppet::Network::RESTServer, "in general" do
  it "should provide a way to specify that an indirection is to be made accessible to clients"
  it "should provide a way to specify that an indirection is to no longer be made accessible to clients"
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
