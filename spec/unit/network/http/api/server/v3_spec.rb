require 'spec_helper'

require 'puppet/network/http'
require 'puppet_spec/network'

describe Puppet::Network::HTTP::API::Server::V3 do
  include PuppetSpec::Network

  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }
  let(:server_url_prefix) { "#{Puppet::Network::HTTP::SERVER_URL_PREFIX}/v3" }
  let(:server_routes) {
    Puppet::Network::HTTP::Route.
        path(Regexp.new("#{Puppet::Network::HTTP::SERVER_URL_PREFIX}/")).
        any.
        chain(Puppet::Network::HTTP::API::Server::V3.routes)
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

  it "matches only complete routes" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{server_url_prefix}/foo/environments")
    expect { server_routes.process(request, response) }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError)

    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{server_url_prefix}/foo/environment/production")
    expect { server_routes.process(request, response) }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError)
  end

  it "mounts indirected routes" do
    request = Puppet::Network::HTTP::Request.
        from_hash(:path => "#{server_url_prefix}/node/foo",
                  :params => {:environment => "production"},
                  :headers => {"accept" => "application/json"})
    server_routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "responds to unknown paths by raising not_found_error" do
    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{server_url_prefix}/unknown")

    expect {
      server_routes.process(request, response)
    }.to raise_error(not_found_error)
  end

  it "checks authorization for indirected routes" do
    Puppet::Network::Authorization.authconfigloader_class = nil

    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{server_url_prefix}/catalog/foo")
    expect {
      server_routes.process(request, response)
    }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotAuthorizedError, %r{Not Authorized: Forbidden request: /puppet/v3/catalog/foo \(method GET\)})
  end

  it "checks authorization for environments" do
    Puppet::Network::Authorization.authconfigloader_class = nil

    request = Puppet::Network::HTTP::Request.from_hash(:path => "#{server_url_prefix}/environments")
    expect {
      server_routes.process(request, response)
    }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotAuthorizedError, %r{Not Authorized: Forbidden request: /puppet/v3/environments \(method GET\)})
  end
end
