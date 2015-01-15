require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::V2 do
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

  it "mounts the environments endpoint" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "/v2.0/environments")
    Puppet::Network::HTTP::API::V2.routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "responds to unknown paths with a 404" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "/v2.0/unknown")

    expect do
      Puppet::Network::HTTP::API::V2.routes.process(request, response)
    end.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError)
  end
end
