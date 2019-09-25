require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Client do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { described_class.new(ssl_context: ssl_context) }
  let(:uri) { URI.parse('https://www.example.com') }

  context "when connecting" do
    it 'connects to HTTP URLs' do
      uri = URI.parse('http://www.example.com')

      client.connect(uri) do |http|
        expect(http.address).to eq('www.example.com')
        expect(http.port).to eq(80)
        expect(http).to_not be_use_ssl
      end
    end

    it 'connects to HTTPS URLs' do
      client.connect(uri) do |http|
        expect(http.address).to eq('www.example.com')
        expect(http.port).to eq(443)
        expect(http).to be_use_ssl
      end
    end
  end

  context "when closing" do
    it "closes all connections in the pool" do
      pool = double('pool')
      expect(pool).to receive(:close)

      client = described_class.new(pool: pool, ssl_context: ssl_context)
      client.close
    end
  end

  context "for GET requests" do
    it "includes default HTTP headers" do
      stub_request(:get, uri).with(headers: {'X-Puppet-Version' => /./, 'User-Agent' => /./})

      client.get(uri)
    end

    it "stringifies keys and encodes values in the query" do
      stub_request(:get, uri).with(query: "foo=bar%3Dbaz")

      client.get(uri, params: {:foo => "bar=baz"})
    end

    it "includes custom headers" do
      stub_request(:get, uri).with(headers: { 'X-Foo' => 'Bar' })

      client.get(uri, headers: {'X-Foo' => 'Bar'})
    end

    it "returns the response" do
      stub_request(:get, uri)

      response = client.get(uri)
      expect(response).to be_an_instance_of(Net::HTTPOK)
      expect(response.code).to eq("200")
    end
  end
end
