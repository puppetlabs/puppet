require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::V2 do
  it "responds to unknown paths with a 404" do
    response = Puppet::Network::HTTP::MemoryResponse.new
    request = Puppet::Network::HTTP::Request.from_hash(:path => "/v2.0/unknown")

    expect do
      Puppet::Network::HTTP::API::V2.routes.process(request, response)
    end.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError)
  end
end
