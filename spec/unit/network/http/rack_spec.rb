#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/network/handler'
require 'puppet/network/http/rack' if Puppet.features.rack?

describe "Puppet::Network::HTTP::Rack", :if => Puppet.features.rack? do
  describe "while initializing" do

    it "should require a protocol specification" do
      Proc.new { Puppet::Network::HTTP::Rack.new({}) }.should raise_error(ArgumentError)
    end

    it "should not accept imaginary protocols" do
      Proc.new { Puppet::Network::HTTP::Rack.new({:protocols => [:foo]}) }.should raise_error(ArgumentError)
    end

    it "should accept the REST protocol" do
      Proc.new { Puppet::Network::HTTP::Rack.new({:protocols => [:rest]}) }.should_not raise_error(ArgumentError)
    end

    it "should create a RackREST instance" do
      Puppet::Network::HTTP::RackREST.expects(:new)
      Puppet::Network::HTTP::Rack.new({:protocols => [:rest]})
    end

    describe "with XMLRPC enabled" do

      it "should require XMLRPC handlers" do
        Proc.new { Puppet::Network::HTTP::Rack.new({:protocols => [:xmlrpc]}) }.should raise_error(ArgumentError)
      end

      it "should create a RackXMLRPC instance" do
        Puppet::Network::HTTP::RackXMLRPC.expects(:new)
        Puppet::Network::HTTP::Rack.new({:protocols => [:xmlrpc], :xmlrpc_handlers => [:Status]})
      end

    end

  end

  describe "when called" do

    before :all do
      @app = Puppet::Network::HTTP::Rack.new({:protocols => [:rest]})
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
      Proc.new { @linted.call(@env) }.should_not raise_error
    end

    it "should finish() the Response" do
      Rack::Response.any_instance.expects(:finish).once
      @app.call(@env) # can't lint when finish is a stub
    end

  end

  describe "when serving XMLRPC" do

    before :all do
      @app = Puppet::Network::HTTP::Rack.new({:protocols => [:rest, :xmlrpc], :xmlrpc_handlers => [:Status]})
      @linted = Rack::Lint.new(@app)
    end

    before :each do
      @env = Rack::MockRequest.env_for('/RPC2', :method => 'POST')
    end

    it "should use RackXMLRPC to serve /RPC2 requests" do
      Puppet::Network::HTTP::RackXMLRPC.any_instance.expects(:process).once
      @linted.call(@env)
    end

  end

end

