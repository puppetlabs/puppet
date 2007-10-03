#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_controller'

describe Puppet::Network::RESTController, "in general" do
  it "should take arguments from server, call the appropriate method with correct arguments (parameter passing)"
  it "should serialize result data when methods are handled"
  it "should serialize an error condition when indirection method call generates an exception"
end
