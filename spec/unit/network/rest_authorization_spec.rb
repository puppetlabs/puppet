#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_authorization'

class RestAuthorized
  include Puppet::Network::RestAuthorization
end


describe Puppet::Network::RestAuthorization do
  before :each do
    @auth = RestAuthorized.new
    @authconig = stub 'authconfig'
    @auth.stubs(:authconfig).returns(@authconfig)

    @request = stub_everything 'request'
    @request.stubs(:method).returns(:find)
    @request.stubs(:node).returns("node")
    @request.stubs(:ip).returns("ip")
  end

  describe "when testing request authorization" do
    it "should delegate to the current rest authconfig" do
      @authconfig.expects(:allowed?).with(@request).returns(true)

      @auth.check_authorization(@request)
    end

    it "should raise an AuthorizationError if authconfig raises an AuthorizationError" do
      @authconfig.expects(:allowed?).with(@request).raises(Puppet::Network::AuthorizationError.new("forbidden"))

      lambda { @auth.check_authorization(@request) }.should raise_error(Puppet::Network::AuthorizationError)
    end

    it "should not raise an AuthorizationError if request is allowed" do
      @authconfig.expects(:allowed?).with(@request).returns(true)

      lambda { @auth.check_authorization(@request) }.should_not raise_error(Puppet::Network::AuthorizationError)
    end
  end
end
