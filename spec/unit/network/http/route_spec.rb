#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/indirector_testing'

require 'puppet/network/http'

describe Puppet::Network::HTTP::Route do
  def request(method, path)
    Puppet::Network::HTTP::Request.from_hash({
      :method => method,
      :path => path,
      :routing_path => path })
  end

  def respond(text)
    lambda { |req, res| res.respond_with(200, "text/plain", text) }
  end

  let(:req) { request("GET", "/vtest/foo") }
  let(:res) { Puppet::Network::HTTP::MemoryResponse.new }

  describe "an HTTP Route" do
    it "can match a request" do
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest})
      expect(route.matches?(req)).to be_truthy
    end

    it "will raise a Method Not Allowed error when no handler for the request's method is given" do
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest}).post(respond("ignored"))
      expect do
        route.process(req, res)
      end.to raise_error(Puppet::Network::HTTP::Error::HTTPMethodNotAllowedError)
    end

    it "can match any HTTP method" do
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest/foo}).any(respond("used"))
      expect(route.matches?(req)).to be_truthy

      route.process(req, res)

      expect(res.body).to eq("used")
    end

    it "processes DELETE requests" do
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest/foo}).delete(respond("used"))

      route.process(request("DELETE", "/vtest/foo"), res)

      expect(res.body).to eq("used")
    end

    it "does something when it doesn't know the verb" do
      route = Puppet::Network::HTTP::Route.path(%r{^/vtest/foo})

      expect do
        route.process(request("UNKNOWN", "/vtest/foo"), res)
      end.to raise_error(Puppet::Network::HTTP::Error::HTTPMethodNotAllowedError, /UNKNOWN/)
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
      expect(ignored_called).to be_falsey
    end

    it "chains to other routes after calling its handlers" do
      inner_route = Puppet::Network::HTTP::Route.path(%r{^/inner}).any(respond("inner"))
      unused_inner_route = Puppet::Network::HTTP::Route.path(%r{^/unused_inner}).any(respond("unused"))

      top_route = Puppet::Network::HTTP::Route.path(%r{^/vtest}).any(respond("top")).chain(unused_inner_route, inner_route)
      top_route.process(request("GET", "/vtest/inner"), res)

      expect(res.body).to eq("topinner")
    end
  end
end
