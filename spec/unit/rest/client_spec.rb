require 'spec_helper'

require 'puppet/rest/client'
require 'puppet/rest/route'

describe Puppet::Rest::Client do
  context "when creating a new client" do
    let(:route) { Puppet::Rest::Route.new(api: "/fake_api/v1",
                                          srv_service: :fakeservice,
                                          default_server: "myserver.com",
                                          default_port: 555) }
    let(:ssl_store) { mock 'store' }
    let(:http) { stub_everything('http', :request_filter => []) }
    let(:server_resolver) { mock 'resolver', :select_server_and_port => [ route.default_server, route.default_port ] }

    it "configures a base URL based on the provided route" do
      url = "https://myserver.com:555/fake_api/v1"
      http.expects(:base_url=).with(url)
      client = Puppet::Rest::Client.new(route,
                                        client: http,
                                        ssl_store: ssl_store,
                                        server_resolver: server_resolver)
      expect(client.base_url).to eq(url)
    end

    it "initializes itself with basic defaults" do
      Puppet::Rest::Client.expects(:default_client).returns(http)
      OpenSSL::X509::Store.expects(:new).returns(ssl_store)
      Puppet::Rest::ServerResolver.expects(:new).returns(server_resolver)
      http.expects(:receive_timeout=).with(3600)
      http.expects(:cert_store=).with(ssl_store)
      Puppet::Rest::Client.new(route)
    end

    it "uses a given client and SSL store when provided" do
      http.expects(:cert_store=).with(ssl_store)
      Puppet::Rest::Client.new(route, client: http, ssl_store: ssl_store)
    end

    it "configures a receive timeout when provided" do
      http.expects(:receive_timeout=).with(10)
      Puppet::Rest::Client.new(route, client: http, receive_timeout: 10)
    end
  end

  context "when making requests" do
    let(:route) { Puppet::Rest::Route.new(api: "/fake_api/v1",
                                          srv_service: :fakeservice,
                                          default_server: "myserver.com",
                                          default_port: 555) }
    let(:http) { stub_everything('http', :request_filter => []) }
    let(:client) { Puppet::Rest::Client.new(route, client: http) }
    let(:endpoint) { "/data" }

    it "makes a GET request given a URL" do
      http.expects(:get).with(endpoint, query: nil, header: nil).returns("response")
      client.get(endpoint)
    end

    it "accepts a query hash" do
      query = { 'environment' => 'production' }
      http.expects(:get).with(endpoint, query: query, header: nil)
      client.get(endpoint, query: query)
    end

    it "accepts a header hash" do
      header = { 'Accept' => 'text/plain' }
      http.expects(:get).with(endpoint, query: nil, header: header)
      client.get(endpoint, header: header)
    end

    it "returns a wrapped response object" do
      fake_response = mock('resp', :status => HTTP::Status::OK)
      http.expects(:get).with(endpoint, query: nil, header: nil).returns(fake_response)
      response = client.get(endpoint)
      expect(response).to be_a(Puppet::Rest::Response)
      expect(response.status_code).to eq(200)
    end
  end
end
