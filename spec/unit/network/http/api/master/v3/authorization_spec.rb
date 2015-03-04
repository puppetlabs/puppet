require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::Master::V3::Authorization do
  HTTP = Puppet::Network::HTTP

  let(:response) { HTTP::MemoryResponse.new }
  let(:authz) { HTTP::API::Master::V3::Authorization.new }
  let(:noop_handler) {
    lambda do |request, response|
    end
  }

  it "accepts v3 api requests that match allowed authconfig entries" do
    request = HTTP::Request.from_hash({
      :path => "/v3/environments",
      :method => "GET",
      :params => { :authenticated => true, :node => "testing", :ip => "127.0.0.1" }
    })

    authz.stubs(:authconfig).returns(Puppet::Network::AuthConfigParser.new(<<-AUTH).parse)
path /v3/environments
method find
allow *
    AUTH

    handler = authz.wrap do
      noop_handler
    end

    expect do
      handler.call(request, response)
    end.to_not raise_error
  end

  it "rejects v3 api requests that are disallowed by authconfig entries" do
    request = HTTP::Request.from_hash({
      :path => "/v3/environments",
      :method => "GET",
      :params => { :authenticated => true, :node => "testing", :ip => "127.0.0.1" }
    })

    authz.stubs(:authconfig).returns(Puppet::Network::AuthConfigParser.new(<<-AUTH).parse)
path /v3/environments
method find
auth any
deny testing
    AUTH

    handler = authz.wrap do
      noop_handler
    end

    expect do
      handler.call(request, response)
    end.to raise_error(HTTP::Error::HTTPNotAuthorizedError, /Forbidden request/)
  end
end
