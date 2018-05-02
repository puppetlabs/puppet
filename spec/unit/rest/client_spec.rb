require 'spec_helper'

require 'puppet/rest/client'

describe Puppet::Rest::Client do
  include PuppetSpec::Files

  context "when creating a new client" do
    let(:ssl_store) { mock 'store' }
    let(:http) { stub_everything('http', :request_filter => []) }

    it "should create a basic http client and ssl store by default" do
      Puppet::Rest::Client.expects(:default_client).returns(http)
      OpenSSL::X509::Store.expects(:new).returns(ssl_store)
      http.expects(:receive_timeout=).with(3600)
      http.expects(:cert_store=).with(ssl_store)
      Puppet::Rest::Client.new()
    end

    it "should use a given client and SSL store when provided" do
      http.expects(:cert_store=).with(ssl_store)
      Puppet::Rest::Client.new(client: http, ssl_store: ssl_store)
    end

    it "the recieve timeout should be configurable" do
      http.expects(:receive_timeout=).with(10)
      Puppet::Rest::Client.new(client: http, receive_timeout: 10)
    end
  end

  context "when making requests" do
    let(:http) { stub_everything('http', :request_filter => []) }
    let(:client) { Puppet::Rest::Client.new(client: http) }

    it "should make a GET request given a URL" do
      url = "https://foo.com"
      http.expects(:get).with(url, query: nil, header: nil).returns("response")
      client.get(url)
    end

    it "should accept a query hash" do
      url = "https://foo.com"
      query = { 'environment' => 'production' }
      http.expects(:get).with(url, query: query, header: nil)
      client.get(url, query: query)
    end

    it "should accept a header hash" do
      url = "https://foo.com"
      header = { 'Accept' => 'text/plain' }
      http.expects(:get).with(url, query: nil, header: header)
      client.get(url, header: header)
    end
  end
end
