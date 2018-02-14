#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/handler'

require 'puppet/indirector_testing'

require 'puppet/network/authorization'

require 'puppet/network/http'

describe Puppet::Network::HTTP::Handler do
  before :each do
    Puppet::IndirectorTesting.indirection.terminus_class = :memory
  end

  let(:indirection) { Puppet::IndirectorTesting.indirection }

  def a_request(method = "HEAD", path = "/production/#{indirection.name}/unknown")
    {
      :accept_header => "application/json",
      :content_type_header => "application/json",
      :method => method,
      :path => path,
      :params => {},
      :client_cert => nil,
      :headers => {},
      :body => nil
    }
  end

  let(:handler) { PuppetSpec::Handler.new() }

  describe "the HTTP Handler" do
    def respond(text)
      lambda { |req, res| res.respond_with(200, "text/plain", text) }
    end

    it "hands the request to the first route that matches the request path" do
      handler = PuppetSpec::Handler.new(
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
        PuppetSpec::Handler.new(
          Puppet::Network::HTTP::Route.path(%r{^/foo}).get(respond("ignored")),
          Puppet::Network::HTTP::Route.path(%r{^/foo}).post(respond("also ignored"))
        )
      end.to raise_error(ArgumentError)
    end

    it "raises an HTTP not found error if no routes match" do
      handler = PuppetSpec::Handler.new

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      res_body = JSON(res[:body])

      expect(res[:content_type_header]).to eq("application/json; charset=utf-8")
      expect(res_body["issue_kind"]).to eq("HANDLER_NOT_FOUND")
      expect(res_body["message"]).to eq("Not Found: No route for GET /vtest/foo")
      expect(res[:status]).to eq(404)
    end

    it "returns a structured error response when the server encounters an internal error" do
      error = StandardError.new("the sky is falling!")
      original_stacktrace = ['a.rb', 'b.rb']
      error.set_backtrace(original_stacktrace)

      handler = PuppetSpec::Handler.new(
        Puppet::Network::HTTP::Route.path(/.*/).get(lambda { |_, _| raise error}))

      # Stacktraces should be included in logs
      Puppet.expects(:err).with("Server Error: the sky is falling!\na.rb\nb.rb")

      req = a_request("GET", "/vtest/foo")
      res = {}

      handler.process(req, res)

      res_body = JSON(res[:body])

      expect(res[:content_type_header]).to eq("application/json; charset=utf-8")
      expect(res_body["issue_kind"]).to eq(Puppet::Network::HTTP::Issues::RUNTIME_ERROR.to_s)
      expect(res_body["message"]).to eq("Server Error: the sky is falling!")
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

      p = PuppetSpec::HandlerProfiler.new

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

    it "should still find the correct format if content type contains charset information" do
      request = Puppet::Network::HTTP::Request.new({ 'content-type' => "text/plain; charset=UTF-8" },
                                                   {}, 'GET', '/', nil)
      expect(request.formatter.name).to eq(:s)
    end

    # PUP-3272
    # This used to be for YAML, and doing a to_yaml on an array.
    # The result with to_json is something different, the result is a string
    # Which seems correct. Looks like this was some kind of nesting option "yaml inside yaml" ?
    # Removing the test
#    it "should deserialize JSON parameters" do
#      params = {'my_param' => [1,2,3].to_json}
#
#      decoded_params = handler.send(:decode_params, params)
#
#      decoded_params.should == {:my_param => [1,2,3]}
#    end
  end

  describe "when resolving node" do
    it "should use a look-up from the ip address" do
      Resolv.expects(:getname).with("1.2.3.4").returns("host.domain.com")

      handler.resolve_node(:ip => "1.2.3.4")
    end

    it "should return the look-up result" do
      Resolv.stubs(:getname).with("1.2.3.4").returns("host.domain.com")

      expect(handler.resolve_node(:ip => "1.2.3.4")).to eq("host.domain.com")
    end

    it "should return the ip address if resolving fails" do
      Resolv.stubs(:getname).with("1.2.3.4").raises(RuntimeError, "no such host")

      expect(handler.resolve_node(:ip => "1.2.3.4")).to eq("1.2.3.4")
    end
  end
end
