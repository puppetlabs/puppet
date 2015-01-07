require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::CA::V1 do
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }
  let(:ca_url_prefix) { "#{Puppet::Network::HTTP::CA_URL_PREFIX}/v1"}

  let(:ca_routes) {
    Puppet::Network::HTTP::Route.
      path(Regexp.new("#{Puppet::Network::HTTP::CA_URL_PREFIX}/")).
      any.
      chain(Puppet::Network::HTTP::API::CA::V1.routes)
  }

  it "mounts ca routes" do
    Puppet::SSL::Certificate.indirection.stubs(:find).returns "foo"
    request = Puppet::Network::HTTP::Request.
        from_hash(:path => "#{ca_url_prefix}/certificate/foo",
                  :params => {:environment => "production"},
                  :headers => {"accept" => "s"})
    ca_routes.process(request, response)

    expect(response.code).to eq(200)
  end
end
