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

  let(:handler) { TestingHandler.new() }

  describe "the HTTP Handler" do
    def respond(text)
      lambda { |req, res| res.respond_with(200, "text/plain", text) }
    end

    it "hands the request to the first route that matches the request path" do
      handler = TestingHandler.new(
        Puppet::Network::HTTP::Route.path(%r{^/foo}).get(respond("skipped")),
        Puppet::Network::HTTP::Route.path(%r{^/vtest}).get(respond("used")),
        Puppet::Network::HTTP::Route.path(%r{^/vtest/foo}).get(respond("ignored")))

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      expect(res[:body]).to eq("used")
    end

    it "raises an error if multiple routes with the same path regex are registered" do
      expect do
        handler = TestingHandler.new(
          Puppet::Network::HTTP::Route.path(%r{^/foo}).get(respond("ignored")),
          Puppet::Network::HTTP::Route.path(%r{^/foo}).post(respond("also ignored")))
      end.to raise_error(ArgumentError)
    end

    it "raises an HTTP not found error if no routes match" do
      handler = TestingHandler.new

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      res_body = JSON(res[:body])

      expect(res[:content_type_header]).to eq("application/json")
      expect(res_body["issue_kind"]).to eq("HANDLER_NOT_FOUND")
      expect(res_body["message"]).to eq("Not Found: No route for GET /vtest/foo")
      expect(res[:status]).to eq(404)
    end

    it "returns a structured error response with a stacktrace when the server encounters an internal error" do
      handler = TestingHandler.new(
        Puppet::Network::HTTP::Route.path(/.*/).get(lambda { |_, _| raise Exception.new("the sky is falling!")}))

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      res_body = JSON(res[:body])

      expect(res[:content_type_header]).to eq("application/json")
      expect(res_body["issue_kind"]).to eq(Puppet::Network::HTTP::Issues::RUNTIME_ERROR.to_s)
      expect(res_body["message"]).to eq("Server Error: the sky is falling!")
      expect(res_body["stacktrace"].is_a?(Array) && !res_body["stacktrace"].empty?).to be_true
      expect(res_body["stacktrace"][0]).to match("spec/unit/network/http/handler_spec.rb")
      expect(res[:status]).to eq(500)
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

    it "should setup a profiler when the puppet-profiling header exists" do
      request = a_request
      request[:headers][Puppet::Network::HTTP::HEADER_ENABLE_PROFILING.downcase] = "true"

      p = HandlerTestProfiler.new

      Puppet::Util::Profiler.expects(:add_profiler).with { |profiler|
        profiler.is_a? Puppet::Util::Profiler::WallClock
      }.returns(p)

      Puppet::Util::Profiler.expects(:remove_profiler).with { |profiler|
        profiler == p
      }

      handler.process(request, response)
    end

    it "should not setup profiler when the profile parameter is missing" do
      request = a_request
      request[:params] = { }

      Puppet::Util::Profiler.expects(:add_profiler).never

      handler.process(request, response)
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
     response[:content_type_header] = format
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

  class HandlerTestProfiler
    def start(metric, description)
    end

    def finish(context, metric, description)
    end

    def shutdown()
    end
  end
end
