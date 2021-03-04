# Tests the backwards compatibility of our master -> server changes
# in the HTTP API
# This may be removed in Puppet 8
require 'spec_helper'

require 'puppet/network/http'
require 'puppet_spec/network'

describe Puppet::Network::HTTP::API::Master::V3 do
  include PuppetSpec::Network

  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }
  let(:server_url_prefix) { "#{Puppet::Network::HTTP::MASTER_URL_PREFIX}/v3" }
  let(:server_routes) {
    Puppet::Network::HTTP::Route.
        path(Regexp.new("#{Puppet::Network::HTTP::MASTER_URL_PREFIX}/")).
        any.
        chain(Puppet::Network::HTTP::API::Master::V3.routes)
  }

  # simulate puppetserver registering its authconfigloader class
  around :each do |example|
    Puppet::Network::Authorization.authconfigloader_class = Object
    begin
      example.run
    ensure
      Puppet::Network::Authorization.authconfigloader_class = nil
    end
  end

  it "mounts the environments endpoint" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{server_url_prefix}/environments")
    server_routes.process(request, response)

    expect(response.code).to eq(200)
  end
end

