require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Client do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { described_class.new(ssl_context: ssl_context) }

  before :each do
    WebMock.disable_net_connect!
    allow_any_instance_of(Net::HTTP).to receive(:start)
    allow_any_instance_of(Net::HTTP).to receive(:finish)
  end

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
      uri = URI.parse('https://www.example.com')

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
end
