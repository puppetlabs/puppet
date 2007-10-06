#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_controller'

describe Puppet::Network::RESTController, "in general" do
  it "should route GET requests on indirector's name to indirector find for the model class"
  it "should route GET requests on indirector's plural name to indirector search for the model class"
  it "should route DELETE requests on indirector's name to indirector destroy for the model class"
  it "should route POST requests on indirector's name to indirector save for the model class"  
  it "should serialize result data when methods are handled"
  it "should serialize an error condition when indirection method call generates an exception"  
end

__END__

# possible implementation of the satisfying class

class RESTController
  def initialize(klass)
    @klass = klass
  end

  # TODO: is it possible to distinguish from the request object the path which we were called by?
  
  def do_GET(request, response)
    return do_GETS(request, response) if asked_for_plural?(request)
    args = request.something
    result = @klass.find args
    return serialize(result)
  end
  
  def do_GETS(request, response)
    args = request.something
    result = @klass.search args
    return serialize(result)
  end
  
  def do_DELETE(request, response)
    args = request.something
    result = @klass.destroy args
    return serialize(result)
  end
  
  def do_PUT(request, response)
    args = request.something
    obj = @klass.new(args)
    result = obj.save
    return serialize(result)
  end
  
  def do_POST(request, response)
    do_PUT(request, response)
  end
  
  private
  
  def asked_for_plural?(request)
    # TODO: pick apart the request and see if this was trying to do a plural or singular GET
  end
end
