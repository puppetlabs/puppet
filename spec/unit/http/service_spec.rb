require 'spec_helper'
require 'puppet/http'
require 'puppet/file_serving'
require 'puppet/file_serving/content'
require 'puppet/file_serving/metadata'

describe Puppet::HTTP::Service do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:session) { Puppet::HTTP::Session.new(client, []) }
  let(:url) { URI.parse('https://www.example.com') }
  let(:service) { described_class.new(client, session, url) }

  class TestService < Puppet::HTTP::Service
    def get_test(ssl_context)
       @client.get(
        url,
        headers: add_puppet_headers({'Default-Header' => 'default-value'}),
        options: {ssl_context: ssl_context}
      )
    end

    def mime_types(model)
      get_mime_types(model)
    end
  end

  context 'when modifying headers for an http request' do
    let(:service) { TestService.new(client, session, url) }

    it 'adds custom user-specified headers' do
      stub_request(:get, "https://www.example.com/").
         with( headers: { 'Default-Header'=>'default-value', 'Header2'=>'newvalue' })

      Puppet[:http_extra_headers] = 'header2:newvalue'

      service.get_test(ssl_context)
    end

    it 'adds X-Puppet-Profiling header if set' do
      stub_request(:get, "https://www.example.com/").
         with( headers: { 'Default-Header'=>'default-value', 'X-Puppet-Profiling'=>'true' })

      Puppet[:profile] = true

      service.get_test(ssl_context)
    end

    it 'ignores a custom header does not have a value' do
      stub_request(:get, "https://www.example.com/").with do |request|
        expect(request.headers).to include({'Default-Header' => 'default-value'})
        expect(request.headers).to_not include('header-with-no-value')
      end

      Puppet[:http_extra_headers] = 'header-with-no-value:'

      service.get_test(ssl_context)
    end

    it 'ignores a custom header that already exists (case insensitive) in the header hash' do
      stub_request(:get, "https://www.example.com/").
         with( headers: { 'Default-Header'=>'default-value' })

      Puppet[:http_extra_headers] = 'default-header:wrongvalue'

      service.get_test(ssl_context)
    end
  end

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
    expect(client).to receive(:connect).with(url, options: {ssl_context: nil})

    service.connect
  end

  it "accepts an optional ssl_context" do
    other_ctx = Puppet::SSL::SSLContext.new
    expect(client).to receive(:connect).with(url, options: {ssl_context: other_ctx})

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

  it 'returns different mime types for different models' do
    mimes = if Puppet.features.msgpack?
              %w[application/json application/x-msgpack text/pson]
            else
              %w[application/json text/pson]
            end

    service = TestService.new(client, session, url)
    [
      Puppet::Node,
      Puppet::Node::Facts,
      Puppet::Transaction::Report,
      Puppet::FileServing::Metadata,
      Puppet::Status
    ].each do |model|
      expect(service.mime_types(model)).to eq(mimes)
    end

    # These are special
    expect(service.mime_types(Puppet::FileServing::Content)).to eq(%w[application/octet-stream])

    catalog_mimes = if Puppet.features.msgpack?
                      %w[application/vnd.puppet.rich+json application/json application/vnd.puppet.rich+msgpack application/x-msgpack text/pson]
                    else
                      %w[application/vnd.puppet.rich+json application/json application/vnd.puppet.rich+msgpack text/pson]
                    end
    expect(service.mime_types(Puppet::Resource::Catalog)).to eq(catalog_mimes)
  end
end
