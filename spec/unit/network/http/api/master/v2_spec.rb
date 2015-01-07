require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::Master::V2 do
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }
  let(:routes) { Puppet::Network::HTTP::Route.path(Regexp.new("/puppet/")).
                  any.
                  chain(Puppet::Network::HTTP::API::Master::V2.routes) }

  it "mounts the environments endpoint" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "/puppet/v2.0/environments")
    routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "responds to unknown paths with a 404" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "/puppet/v2.0/unknown")

    expect do
      routes.process(request, response)
    end.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError)
  end
end
