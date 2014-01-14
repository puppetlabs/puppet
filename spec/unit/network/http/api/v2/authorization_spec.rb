require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::V2::Authorization do
  HTTP = Puppet::Network::HTTP

  let(:response) { HTTP::MemoryResponse.new }
  let(:authz) { HTTP::API::V2::Authorization.new }

  it "only authorizes GET requests" do
    request = HTTP::Request.from_hash({
      :method => "POST"
    })

    expect do
      authz.call(request, response)
    end.to raise_error(HTTP::Error::HTTPNotAuthorizedError)
  end

  it "accepts v2 api requests that match allowed authconfig entries" do
    request = HTTP::Request.from_hash({
      :path => "/v2.0/environments",
      :method => "GET",
      :params => { :authenticated => true, :node => "testing", :ip => "127.0.0.1" }
    })

    authz.stubs(:authconfig).returns(Puppet::Network::AuthConfigParser.new(<<-AUTH).parse)
path /v2.0/environments
method find
allow *
    AUTH

    expect do
      authz.call(request, response)
    end.to_not raise_error
  end

  it "rejects v2 api requests that are disallowed by authconfig entries" do
    request = HTTP::Request.from_hash({
      :path => "/v2.0/environments",
      :method => "GET",
      :params => { :node => "testing", :ip => "127.0.0.1" }
    })

    authz.stubs(:authconfig).returns(Puppet::Network::AuthConfigParser.new(<<-AUTH).parse)
path /v2.0/environments
method find
auth any
deny testing
    AUTH

    expect do
      authz.call(request, response)
    end.to raise_error(HTTP::Error::HTTPNotAuthorizedError, /Forbidden request/)
  end
end
