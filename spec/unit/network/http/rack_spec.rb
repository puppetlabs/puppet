#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http/rack' if Puppet.features.rack?

describe "Puppet::Network::HTTP::Rack", :if => Puppet.features.rack? do
  describe "when called" do
    before :all do
      @app = Puppet::Network::HTTP::Rack.new()
      # let's use Rack::Lint to verify that we're OK with the rack specification
      @linted = Rack::Lint.new(@app)
    end

    before :each do
      @env = Rack::MockRequest.env_for('/')
    end

    it "should create a Request object" do
      request = Rack::Request.new(@env)
      Rack::Request.expects(:new).returns request
      @linted.call(@env)
    end

    it "should create a Response object" do
      Rack::Response.expects(:new).returns stub_everything
      @app.call(@env) # can't lint when Rack::Response is a stub
    end

    it "should let RackREST process the request" do
      Puppet::Network::HTTP::RackREST.any_instance.expects(:process).once
      @linted.call(@env)
    end

    it "should catch unhandled exceptions from RackREST" do
      Puppet::Network::HTTP::RackREST.any_instance.expects(:process).raises(ArgumentError, 'test error')
      expect { @linted.call(@env) }.not_to raise_error
    end

    it "should finish() the Response" do
      Rack::Response.any_instance.expects(:finish).once
      @app.call(@env) # can't lint when finish is a stub
    end
  end
end
