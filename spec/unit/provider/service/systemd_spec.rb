#!/usr/bin/env rspec
#
# Unit testing for the RedHat service Provider
#
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:systemd)

describe provider_class do
  before :each do
    @class = Puppet::Type.type(:service).provider(:redhat)
    @resource = stub 'resource'
    @resource.stubs(:[]).returns(nil)
    @resource.stubs(:[]).with(:name).returns "myservice.service"
    @provider = provider_class.new
    @resource.stubs(:provider).returns @provider
    @provider.resource = @resource
  end

  [:enabled?, :enable, :disable, :start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      @provider.should respond_to(method)
    end
  end
end
