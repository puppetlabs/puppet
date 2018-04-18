#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet_spec/handler'
require 'puppet/network/http'
require 'puppet/version'

describe Puppet::Network::HTTP::API do
  def respond(text)
    lambda { |req, res| res.respond_with(200, "text/plain", text) }
  end

  describe "#not_found" do
    let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

    let(:routes) {
      Puppet::Network::HTTP::Route.path(Regexp.new("foo")).
      any.
      chain(Puppet::Network::HTTP::Route.path(%r{^/bar$}).get(respond("bar")),
            Puppet::Network::HTTP::API.not_found)
    }

    it "mounts the chained routes" do
      request = Puppet::Network::HTTP::Request.from_hash(:path => "foo/bar")
      routes.process(request, response)

      expect(response.code).to eq(200)
      expect(response.body).to eq("bar")
    end

    it "responds to unknown paths with a 404" do
      request = Puppet::Network::HTTP::Request.from_hash(:path => "foo/unknown")

      expect do
        routes.process(request, response)
      end.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError)
    end
  end

  describe "Puppet API" do
    let(:handler) { PuppetSpec::Handler.new(Puppet::Network::HTTP::API.master_routes,
                                            Puppet::Network::HTTP::API.not_found_upgrade) }

    let(:master_prefix) { Puppet::Network::HTTP::MASTER_URL_PREFIX }

    it "raises a not-found error for non-CA or master routes and suggests an upgrade" do
      req = Puppet::Network::HTTP::Request.from_hash(:path => "/unknown")
      res = {}
      handler.process(req, res)
      expect(res[:status]).to eq(404)
      expect(res[:body]).to include("Puppet version: #{Puppet.version}")
    end

    describe "when processing Puppet 3 routes" do
      it "gives an upgrade message for master routes" do
        req = Puppet::Network::HTTP::Request.from_hash(:path => "/production/node/foo")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(404)
        expect(res[:body]).to include("Puppet version: #{Puppet.version}")
        expect(res[:body]).to include("Supported /puppet API versions: #{Puppet::Network::HTTP::MASTER_URL_VERSIONS}")
      end

      it "gives an upgrade message for CA routes" do
        req = Puppet::Network::HTTP::Request.from_hash(:path => "/production/certificate/foo")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(404)
        expect(res[:body]).to include("Puppet version: #{Puppet.version}")
        expect(res[:body]).to include("Supported /puppet API versions: #{Puppet::Network::HTTP::MASTER_URL_VERSIONS}")
      end
    end

    describe "when processing master routes" do
      it "responds to v3 indirector requests" do
        req = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_prefix}/v3/node/foo",
                                                       :params => {:environment => "production"},
                                                       :headers => {'accept' => "application/json"})
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(200)
      end

      it "responds to v3 environments requests" do
        req = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_prefix}/v3/environments")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(200)
      end

      it "responds with a not found error to non-v3 requests and does not suggest an upgrade" do
        req = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_prefix}/unknown")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(404)
        expect(res[:body]).to include("No route for GET #{master_prefix}/unknown")
        expect(res[:body]).not_to include("Puppet version: #{Puppet.version}")
      end
    end
  end
end
