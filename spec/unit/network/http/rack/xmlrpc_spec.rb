#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/network/handler'
require 'puppet/network/http/rack' if Puppet.features.rack?
require 'puppet/network/http/rack/xmlrpc' if Puppet.features.rack?

describe "Puppet::Network::HTTP::RackXMLRPC", :if => Puppet.features.rack? do
  describe "when initializing" do
    it "should create an Puppet::Network::XMLRPCServer" do
      Puppet::Network::XMLRPCServer.expects(:new).returns stub_everything
      Puppet::Network::HTTP::RackXMLRPC.new([])
    end

    it "should create each handler" do
      handler = stub_everything 'handler'
      Puppet::Network::XMLRPCServer.any_instance.stubs(:add_handler)
      Puppet::Network::Handler.expects(:handler).returns(handler).times(2)
      Puppet::Network::HTTP::RackXMLRPC.new([:foo, :bar])
    end

    it "should add each handler to the XMLRPCserver" do
      handler = stub_everything 'handler'
      Puppet::Network::Handler.stubs(:handler).returns(handler)
      Puppet::Network::XMLRPCServer.any_instance.expects(:add_handler).times(2)
      Puppet::Network::HTTP::RackXMLRPC.new([:foo, :bar])
    end
  end

  describe "when serving a request" do

    before :each do
      foo_handler = stub_everything 'foo_handler'
      Puppet::Network::Handler.stubs(:handler).with(:foo).returns foo_handler
      Puppet::Network::XMLRPCServer.any_instance.stubs(:add_handler)
      Puppet::Network::XMLRPCServer.any_instance.stubs(:process).returns('<xml/>')
      @handler = Puppet::Network::HTTP::RackXMLRPC.new([:foo])
    end

    before :each do
      @response = Rack::Response.new
    end

    def mk_req(opts = {})
      opts[:method] = 'POST' if !opts[:method]
      opts['CONTENT_TYPE'] = 'text/xml; foo=bar' if !opts['CONTENT_TYPE']
      env = Rack::MockRequest.env_for('/RPC2', opts)
      Rack::Request.new(env)
    end

    it "should reject non-POST requests" do
      req = mk_req :method => 'PUT'
      @handler.process(req, @response)
      @response.status.should == 405
    end

    it "should reject non text/xml requests" do
      req = mk_req 'CONTENT_TYPE' => 'yadda/plain'
    end

    it "should create a ClientRequest" do
      cr = Puppet::Network::ClientRequest.new(nil, '127.0.0.1', false)
      Puppet::Network::ClientRequest.expects(:new).returns cr
      req = mk_req
      @handler.process(req, @response)
    end

    it "should let xmlrpcserver process the request" do
      Puppet::Network::XMLRPCServer.any_instance.expects(:process).returns('yay')
      req = mk_req
      @handler.process(req, @response)
    end

    it "should report the response as OK" do
      req = mk_req
      @handler.process(req, @response)
      @response.status.should == 200
    end

    it "should report the response with the correct content type" do
      req = mk_req
      @handler.process(req, @response)
      @response['Content-Type'].should == 'text/xml; charset=utf-8'
    end

    it "should set 'authenticated' to false if no certificate is present" do
      req = mk_req
      Puppet::Network::ClientRequest.expects(:new).with { |node,ip,authenticated| authenticated == false }
      @handler.process(req, @response)
    end

    it "should use the client's ip address" do
      req = mk_req 'REMOTE_ADDR' => 'ipaddress'
      Puppet::Network::ClientRequest.expects(:new).with { |node,ip,authenticated| ip == 'ipaddress' }
      @handler.process(req, @response)
    end

    describe "with pre-validated certificates" do

      it "should use the :ssl_client_header to determine the parameter when looking for the certificate" do
        Puppet.settings.stubs(:value).returns "eh"
        Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
        req = mk_req "myheader" => "/CN=host.domain.com"
        @handler.process(req, @response)
      end

      it "should retrieve the hostname by matching the certificate parameter" do
        Puppet.settings.stubs(:value).returns "eh"
        Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
        Puppet::Network::ClientRequest.expects(:new).with { |node,ip,authenticated| node == "host.domain.com" }
        req = mk_req "myheader" => "/CN=host.domain.com"
        @handler.process(req, @response)
      end

      it "should use the :ssl_client_header to determine the parameter for checking whether the host certificate is valid" do
        Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
        Puppet.settings.expects(:value).with(:ssl_client_verify_header).returns "myheader"
        req = mk_req "myheader" => "SUCCESS", "certheader" => "/CN=host.domain.com"
        @handler.process(req, @response)
      end

      it "should consider the host authenticated if the validity parameter contains 'SUCCESS'" do
        Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
        Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
        Puppet::Network::ClientRequest.expects(:new).with { |node,ip,authenticated| authenticated == true }
        req = mk_req "myheader" => "SUCCESS", "certheader" => "/CN=host.domain.com"
        @handler.process(req, @response)
      end

      it "should consider the host unauthenticated if the validity parameter does not contain 'SUCCESS'" do
        Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
        Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
        Puppet::Network::ClientRequest.expects(:new).with { |node,ip,authenticated| authenticated == false }
        req = mk_req "myheader" => "whatever", "certheader" => "/CN=host.domain.com"
        @handler.process(req, @response)
      end

      it "should consider the host unauthenticated if no certificate information is present" do
        Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
        Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
        Puppet::Network::ClientRequest.expects(:new).with { |node,ip,authenticated| authenticated == false }
        req = mk_req "myheader" => nil, "certheader" => "/CN=host.domain.com"
        @handler.process(req, @response)
      end

      it "should resolve the node name with an ip address look-up if no certificate is present" do
        Puppet.settings.stubs(:value).returns "eh"
        Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
        Resolv.any_instance.expects(:getname).returns("host.domain.com")
        Puppet::Network::ClientRequest.expects(:new).with { |node,ip,authenticated| node == "host.domain.com" }
        req = mk_req "myheader" => nil
        @handler.process(req, @response)
      end
    end
  end
end
