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

    before(:each) do
      route.stubs(:select_server_and_port).returns(["myserver.com", 555])
    end

    it "configures a base URL based on the provided route" do
      url = "https://myserver.com:555/fake_api/v1/"
      http.expects(:base_url=).with(url)
      client = Puppet::Rest::Client.new(route,
                                        client: http,
                                        ssl_store: ssl_store)
      http.expects(:base_url).returns(url)
      expect(client.base_url).to eq(url)
    end

    it "initializes itself with basic defaults" do
      HTTPClient.expects(:new).returns(http)
      OpenSSL::X509::Store.expects(:new).returns(ssl_store)
      Puppet.settings.expects(:[]).with(:http_user_agent)
      Puppet.settings.expects(:[]).with(:http_read_timeout).returns(120)
      Puppet.settings.expects(:[]).with(:http_connect_timeout).returns(10)
      http.expects(:connect_timeout=).with(10)
      http.expects(:receive_timeout=).with(120)
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

    before(:each) do
      route.stubs(:select_server_and_port).returns("myserver.com", 555)
    end

    it "makes a GET request given a URL, query hash, and header hash" do
      query = { 'environment' => 'production' }
      header = { 'Accept' => 'text/plain' }
      http.expects(:get).with(endpoint, query: query, header: header).returns("response")
      client.get(endpoint, query: query, header: header)
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
