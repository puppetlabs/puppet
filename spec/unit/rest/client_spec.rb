require 'spec_helper'

require 'puppet/rest/client'
require 'puppet/rest/route'

describe Puppet::Rest::Client do
  context "when creating a new client" do
    let(:route) { Puppet::Rest::Route.new(api: "/fake_api/v1/",
                                          srv_service: :fakeservice,
                                          default_server: "myserver.com",
                                          default_port: 555) }
    let(:ssl_store) { mock('store') }
    let(:ssl_config) { stub_everything('ssl config') }
    let(:http) { stub_everything('http', :ssl_config => ssl_config) }

    before(:each) do
      route.stubs(:select_server_and_port).returns(["myserver.com", 555])
    end

    it "configures a base URL based on the provided route" do
      url = "https://myserver.com:555/fake_api/v1/"
      http.expects(:base_url=).with() do |arg|
        arg.to_s == url
      end
      client = Puppet::Rest::Client.new(route,
                                        client: http,
                                        ssl_store: ssl_store)
    end

    it "initializes itself with basic defaults" do
      HTTPClient.expects(:new).returns(http)
      OpenSSL::X509::Store.expects(:new).returns(ssl_store)
      # Configure connection with HTTP settings
      Puppet.expects(:[]).with(:http_user_agent)
      Puppet.expects(:[]).with(:http_read_timeout).returns(120)
      Puppet.expects(:[]).with(:http_connect_timeout).returns(10)
      Puppet.expects(:[]).with(:http_debug).returns(true)
      http.expects(:connect_timeout=).with(10)
      http.expects(:receive_timeout=).with(120)
      http.expects(:debug_dev=).with($stderr)

      # Configure verify mode with SSL settings
      ssl_config.expects(:cert_store=).with(ssl_store)
      Puppet.expects(:[]).with(:ssl_client_ca_auth).returns("/fake/path")
      Puppet.expects(:[]).with(:hostcert).returns("/fake/path/mycert")
      ssl_config.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      Puppet::Rest::Client.new(route)
    end

    it "uses a given client and SSL store when provided" do
      ssl_config.expects(:cert_store=).with(ssl_store)
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
    let(:ssl_config) { stub_everything('ssl config') }
    let(:http) { stub_everything('http', :ssl_config => ssl_config) }
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
