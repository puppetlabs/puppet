require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Session do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:uri) { URI.parse('https://www.example.com') }
  let(:good_service) {
    double('good', url: uri, connect: nil)
  }
  let(:bad_service) {
    service = double('bad', url: uri)
    allow(service).to receive(:connect).and_raise(Puppet::HTTP::ConnectionError, 'whoops')
    service
  }

  class DummyResolver
    attr_reader :count

    def initialize(service)
      @service = service
      @count = 0
    end

    def resolve(session, name, ssl_context: nil)
      @count += 1
      return @service if check_connection?(session, @service, ssl_context: ssl_context)
    end

    def check_connection?(session, service, ssl_context: nil)
      service.connect(ssl_context: ssl_context)
      return true
    rescue Puppet::HTTP::ConnectionError => e
      session.add_exception(e)
      Puppet.debug("Connection to #{service.url} failed, trying next route: #{e.message}")
      return false
    end
  end

  context 'when routing' do
    it 'returns the first resolved service' do
      Puppet[:log_level] = :debug
      resolvers = [DummyResolver.new(bad_service), DummyResolver.new(good_service)]
      session = described_class.new(client, resolvers)
      resolved = session.route_to(:ca)

      expect(resolved).to eq(good_service)
      expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Connection to #{uri} failed, trying next route: whoops"))
    end

    it 'only resolves once per session' do
      resolver = DummyResolver.new(good_service)
      session = described_class.new(client, [resolver])
      session.route_to(:ca)
      session.route_to(:ca)

      expect(resolver.count).to eq(1)
    end

    it 'raises if there are no more routes' do
      resolvers = [DummyResolver.new(bad_service)]
      session = described_class.new(client, resolvers)

      expect {
        session.route_to(:ca)
      }.to raise_error(Puppet::HTTP::RouteError, 'No more routes to ca')
    end

    it 'accepts an ssl context to use when connecting' do
      alt_context = Puppet::SSL::SSLContext.new
      expect(good_service).to receive(:connect).with(ssl_context: alt_context)

      resolvers = [DummyResolver.new(good_service)]
      session = described_class.new(client, resolvers)
      session.route_to(:ca, ssl_context: alt_context)
    end

    it 'raises for unknown service names' do
      expect {
        session = described_class.new(client, [])
        session.route_to(:westbound)
      }.to raise_error(ArgumentError, "Unknown service westbound")
    end
  end
end
