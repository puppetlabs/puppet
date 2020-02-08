require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Service do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:session) { Puppet::HTTP::Session.new(client, []) }
  let(:url) { URI.parse('https://www.example.com') }
  let(:service) { described_class.new(client, session, url) }

  it "returns a URI containing the base URL and path" do
    expect(service.with_base_url('/puppet/v3')).to eq(URI.parse("https://www.example.com/puppet/v3"))
  end

  it "doesn't modify frozen the base URL" do
    service = described_class.new(client, session, url.freeze)
    service.with_base_url('/puppet/v3')
  end

  it "percent encodes paths before appending them to the path" do
    expect(service.with_base_url('/path/with/a space')).to eq(URI.parse("https://www.example.com/path/with/a%20space"))
  end

  it "connects to the base URL with a nil ssl context" do
    expect(client).to receive(:connect).with(url, ssl_context: nil)

    service.connect
  end

  it "accepts an optional ssl_context" do
    other_ctx = Puppet::SSL::SSLContext.new
    expect(client).to receive(:connect).with(url, ssl_context: other_ctx)

    service.connect(ssl_context: other_ctx)
  end

  it 'raises for unknown service names' do
    expect {
      described_class.create_service(client, session, :westbound)
    }.to raise_error(ArgumentError, "Unknown service westbound")
  end

  [:ca].each do |name|
    it "returns true for #{name}" do
      expect(described_class.valid_name?(name)).to eq(true)
    end
  end

  it "returns false when the service name is a string" do
    expect(described_class.valid_name?("ca")).to eq(false)
  end

  it "returns false for unknown service names" do
    expect(described_class.valid_name?(:westbound)).to eq(false)
  end
end
