require 'spec_helper'

require 'puppet/network/http'
require 'puppet_spec/network'

describe Puppet::Network::HTTP::API::Master::V3 do
  include PuppetSpec::Network

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

  it "mounts the environment endpoint" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/environment/production")
    master_routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "matches only complete routes" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/foo/environments")
    expect { master_routes.process(request, response) }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError)

    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/foo/environment/production")
    expect { master_routes.process(request, response) }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError)
  end

  it "mounts indirected routes" do
    request = Puppet::Network::HTTP::Request.
        from_hash(:path => "#{master_url_prefix}/node/foo",
                  :params => {:environment => "production"},
                  :headers => {"accept" => "application/json"})
    master_routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "responds to unknown paths by raising not_found_error" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/unknown")

    expect {
      master_routes.process(request, response)
    }.to raise_error(not_found_error)
  end
end
