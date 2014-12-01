require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::V3 do
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }
  let(:url_prefix) { "#{Puppet[:master_url_prefix]}/v3"}
  let(:routes) {
    Puppet::Network::HTTP::Route.
        path(Regexp.new(Puppet[:master_url_prefix])).
        any.
        chain(Puppet::Network::HTTP::API::V3.routes)
  }

  it "mounts the environments endpoint" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{url_prefix}/environments")
    routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "mounts indirected routes" do
    request = Puppet::Network::HTTP::Request.
        from_hash(:path => "#{url_prefix}/node/foo",
                  :params => {:environment => "production"},
                  :headers => {"accept" => "text/pson"})
    routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "responds to unknown paths with a 404" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{url_prefix}/unknown")
    routes.process(request, response)

    expect(response.code).to eq(404)
    expect(response.body).to match("Not Found: Could not find indirection 'unknown'")
  end
end
