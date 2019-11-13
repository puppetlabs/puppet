require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Service do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:url) { URI.parse('https://www.example.com') }
  let(:service) { described_class.new(client, url) }

  it "returns a URI containing the base URL and path" do
    expect(service.with_base_url('/puppet/v3')).to eq(URI.parse("https://www.example.com/puppet/v3"))
  end

  it "doesn't modify frozen the base URL" do
    service = described_class.new(client, url.freeze)
    service.with_base_url('/puppet/v3')
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
end
