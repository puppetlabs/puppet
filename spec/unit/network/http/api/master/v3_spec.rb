require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::Master::V3 do
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }
  let(:master_url_prefix) { "#{Puppet::Network::HTTP::MASTER_URL_PREFIX}/v3" }
  let(:master_routes) {
    Puppet::Network::HTTP::Route.
        path(Regexp.new("#{Puppet::Network::HTTP::MASTER_URL_PREFIX}/")).
        any.
        chain(Puppet::Network::HTTP::API::Master::V3.routes)
  }

  it "mounts the environments endpoint" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/environments")
    master_routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "mounts indirected routes" do
    request = Puppet::Network::HTTP::Request.
        from_hash(:path => "#{master_url_prefix}/node/foo",
                  :params => {:environment => "production"},
                  :headers => {"accept" => "text/pson"})
    master_routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "responds to unknown paths with a 404" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/unknown")
    master_routes.process(request, response)

    expect(response.code).to eq(404)
    expect(response.body).to match("Not Found: Could not find indirection 'unknown'")
  end
end
