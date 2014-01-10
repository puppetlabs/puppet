#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/indirector_testing'

require 'puppet/network/http'

describe Puppet::Network::HTTP::Route do
  def new_request(method, path)
    Puppet::Network::HTTP::Request.new({'accept' => 'pson', 'content-type' => 'text/yaml'}, {}, method, path, nil, nil)
  end

  def respond(text)
    lambda { |req, res| res.respond_with(200, "text/plain", text) }
  end

  let(:req) { new_request("GET", "/vtest/foo") }
  let(:res) { Puppet::Network::HTTP::Response.new(TestingHandler.new(), {}) }

  describe "an HTTP Route" do
    it "can match a request" do
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest})
      expect(route.matches?(req)).to be_true
    end

    it "will raise a Method Not Allowed error when no handler for the request's method is given" do
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest}).post(respond("ignored"))
      expect do
        route.process(req, res)
      end.to raise_error(Puppet::Network::HTTP::Error::HTTPMethodNotAllowedError)
    end

    it "can match any HTTP method" do
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest/foo}).any(respond("used"))
      expect(route.matches?(req)).to be_true

      route.process(req, res)

      expect(res.fields[:body]).to eq("used")
    end

    it "calls the method handlers in turn" do
      call_count = 0
      handler = lambda { |request, response| call_count += 1 }
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest/foo}).get(handler, handler)

      route.process(req, res)
      expect(call_count).to eq(2)
    end

    it "stops calling handlers if one of them raises an error" do
      ignored_called = false
      ignored = lambda { |req, res| ignored_called = true }
      raise_error = lambda { |req, res| raise Puppet::Network::HTTP::Error::HTTPNotAuthorizedError, "go away" }
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest/foo}).get(raise_error, ignored)

      expect do
        route.process(req, res)
      end.to raise_error(Puppet::Network::HTTP::Error::HTTPNotAuthorizedError)
      expect(ignored_called).to be_false
    end
  end

  class TestingHandler
    include Puppet::Network::HTTP::Handler
    def initialize(* routes)
      register(routes)
    end

    def set_content_type(response, format)
    end

    def set_response(response, body, status = 200)
      response[:body] = body
      response[:status] = status
    end
  end

  class Puppet::Network::HTTP::Response
    def fields
      return @response
    end
  end
end
