#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::API do
  def respond(text)
    lambda { |req, res| res.respond_with(200, "text/plain", text) }
  end

  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

  let(:routes) {
    Puppet::Network::HTTP::Route.path(Regexp.new("foo")).
    any.
    chain(Puppet::Network::HTTP::Route.path(%r{^/bar$}).get(respond("bar")),
          Puppet::Network::HTTP::API.not_found)
  }

  it "mounts the bar endpoint" do
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


