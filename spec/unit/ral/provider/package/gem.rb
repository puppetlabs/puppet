#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../../spec_helper'
require 'puppet/provider/package/gem'

provider_class = Puppet::Type.type(:package).provider(:gem)

describe provider_class do
  it "should have an install method" do
    @provider = provider_class.new
    @provider.should respond_to(:install)
  end

  describe "when installing" do
    before do
      # Create a mock resource
      @resource = mock 'resource'

      # A catch all; no parameters set
      @resource.stubs(:[]).returns nil

      # We have to set a name, though
      @resource.stubs(:[]).with(:name).returns "myresource"

      # BTW, you get odd error messages from rspec if you forget to mock "should" here...
      @resource.stubs(:should).with(:ensure).returns :installed

      @provider = provider_class.new
      @provider.stubs(:resource).returns @resource
      # Create a provider that uses the mock
#      @provider = provider_class.new(@resource)
    end

    it "should execute the gem command with 'install', dependencies, and the package name" do
      @provider.expects(:execute).with(provider_class.command(:gemcmd), 'install', "--include-dependences", "myresource")
      @provider.install
    end
  end
end
