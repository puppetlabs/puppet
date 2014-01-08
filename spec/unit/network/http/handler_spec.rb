#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/indirector_testing'

require 'puppet/network/authorization'
require 'puppet/network/authentication'

require 'puppet/network/http'

describe Puppet::Network::HTTP::Handler do
  before :each do
    Puppet::IndirectorTesting.indirection.terminus_class = :memory
  end

  let(:indirection) { Puppet::IndirectorTesting.indirection }

  def a_request(method = "HEAD", path = "/production/#{indirection.name}/unknown")
    {
      :accept_header => "pson",
      :content_type_header => "text/yaml",
      :http_method => method,
      :path => path,
      :params => {},
      :client_cert => nil,
      :headers => {},
      :body => nil
    }
  end

  let(:handler) { TestingHandler.new(nil) }

  describe "when creating a handler" do
    def respond(text)
      lambda { |req, res| res.respond_with(200, "text/plain", text) }
    end

    it "hands the request to the first handler that matches the request path" do
      handler = TestingHandler.new(
        Puppet::Network::HTTP::Route.get(%r{^/foo}, respond("skipped")),
        Puppet::Network::HTTP::Route.get(%r{^/vtest}, respond("used")),
        Puppet::Network::HTTP::Route.get(%r{^/vtest/foo}, respond("never consulted")))

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      expect(res[:body]).to eq("used")
    end

    it "does not hand requests to routes that specify a different HTTP method than the request" do
      handler = TestingHandler.new(
        Puppet::Network::HTTP::Route.post(%r{^/vtest}, respond("skipped")),
        Puppet::Network::HTTP::Route.get(%r{^/vtest}, respond("used")))

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      expect(res[:body]).to eq("used")
    end

    it "allows routes to match any HTTP method" do
      handler = TestingHandler.new(
        Puppet::Network::HTTP::Route.post(%r{^/vtest/foo}, respond("skipped")),
        Puppet::Network::HTTP::Route.any(%r{^/vtest/foo}, respond("used")),
        Puppet::Network::HTTP::Route.get(%r{^/vtest/foo}, respond("ignored")))

        req = a_request("GET", "/vtest/foo")
        res = {}

        handler.process(req, res)

        expect(res[:body]).to eq("used")
    end

    it "raises an HTTP not found error if no routes match" do
      handler = TestingHandler.new

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      expect(res[:body]).to eq("Not Found: No route for GET /vtest/foo")
      expect(res[:status]).to eq(404)
    end

    it "calls each route's handlers in turn" do
      call_count = 0
      route_handler = lambda { |request, response| call_count += 1 }
      handler = TestingHandler.new(
        Puppet::Network::HTTP::Route.get(%r{^/vtest/foo}, route_handler, route_handler))

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      expect(call_count).to eq(2)
    end

    it "stops calling handlers if one of them raises an error" do
      ignored_called = false
      ignored = lambda { |req, res| ignored_called = true }
      raise_error = lambda { |req, res| raise Puppet::Network::HTTP::Handler::HTTPNotAuthorizedError, "go away" }

      handler = TestingHandler.new(
        Puppet::Network::HTTP::Route.get(%r{^/vtest/foo}, raise_error, ignored))

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      expect(res[:status]).to eq(403)
      expect(ignored_called).to be_false
    end
  end

  describe "when processing a request" do
    let(:response) do
      { :status => 200 }
    end

    before do
      handler.stubs(:check_authorization)
      handler.stubs(:warn_if_near_expiration)
    end

    it "should check the client certificate for upcoming expiration" do
      request = a_request
      cert = mock 'cert'
      handler.expects(:client_cert).returns(cert).with(request)
      handler.expects(:warn_if_near_expiration).with(cert)

      handler.process(request, response)
    end

    it "should setup a profiler when the puppet-profiling header exists" do
      request = a_request
      request[:headers][Puppet::Network::HTTP::HEADER_ENABLE_PROFILING.downcase] = "true"

      handler.process(request, response)

      Puppet::Util::Profiler.current.should be_kind_of(Puppet::Util::Profiler::WallClock)
    end

    it "should not setup profiler when the profile parameter is missing" do
      request = a_request
      request[:params] = { }

      handler.process(request, response)

      Puppet::Util::Profiler.current.should == Puppet::Util::Profiler::NONE
    end

    it "should raise an error if the request is formatted in an unknown format" do
      handler.stubs(:content_type_header).returns "unknown format"
      lambda { handler.request_format(request) }.should raise_error
    end

    it "should still find the correct format if content type contains charset information" do
      request = Puppet::Network::HTTP::Request.new({ 'content-type' => "text/plain; charset=UTF-8" },
                                                   {}, 'GET', '/', nil)
      request.format.should == "s"
    end

    it "should deserialize YAML parameters" do
      params = {'my_param' => [1,2,3].to_yaml}

      decoded_params = handler.send(:decode_params, params)

      decoded_params.should == {:my_param => [1,2,3]}
    end

    it "should ignore tags on YAML parameters" do
      params = {'my_param' => "--- !ruby/object:Array {}"}

      decoded_params = handler.send(:decode_params, params)

      decoded_params[:my_param].should be_a(Hash)
    end
  end


  describe "when resolving node" do
    it "should use a look-up from the ip address" do
      Resolv.expects(:getname).with("1.2.3.4").returns("host.domain.com")

      handler.resolve_node(:ip => "1.2.3.4")
    end

    it "should return the look-up result" do
      Resolv.stubs(:getname).with("1.2.3.4").returns("host.domain.com")

      handler.resolve_node(:ip => "1.2.3.4").should == "host.domain.com"
    end

    it "should return the ip address if resolving fails" do
      Resolv.stubs(:getname).with("1.2.3.4").raises(RuntimeError, "no such host")

      handler.resolve_node(:ip => "1.2.3.4").should == "1.2.3.4"
    end
  end

  class TestingHandler
    include Puppet::Network::HTTP::Handler

    def initialize(* routes)
      register(routes)
    end

    def set_content_type(response, format)
      "my_result"
    end

    def set_response(response, body, status = 200)
      response[:body] = body
      response[:status] = status
    end

    def http_method(request)
      request[:http_method]
    end

    def path(request)
      request[:path]
    end

    def params(request)
      request[:params]
    end

    def client_cert(request)
      request[:client_cert]
    end

    def body(request)
      request[:body]
    end

    def headers(request)
      request[:headers] || {}
    end
  end
end
