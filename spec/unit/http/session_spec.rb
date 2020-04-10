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
    create_bad_service
  }

  def create_bad_service(failure_message = 'whoops')
    service = double('bad', url: uri)
    allow(service).to receive(:connect).and_raise(Puppet::HTTP::ConnectionError, failure_message)
    service
  end

  class DummyResolver < Puppet::HTTP::Resolver
    attr_reader :count

    def initialize(service)
      @service = service
      @count = 0
    end

    def resolve(session, name, ssl_context: nil, error_handler: nil)
      @count += 1
      return @service if check_connection?(session, @service, ssl_context: ssl_context, error_handler: error_handler)
    end
  end

  context 'when routing' do
    it 'returns the first resolved service' do
      resolvers = [DummyResolver.new(bad_service), DummyResolver.new(good_service)]
      session = described_class.new(client, resolvers)
      resolved = session.route_to(:ca)

      expect(resolved).to eq(good_service)
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

    it 'logs all routing failures as errors when there are no more routes' do
      resolvers = [DummyResolver.new(create_bad_service('whoops1')), DummyResolver.new(create_bad_service('whoops2'))]
      session = described_class.new(client, resolvers)

      expect {
        session.route_to(:ca)
      }.to raise_error(Puppet::HTTP::RouteError, 'No more routes to ca')

      expect(@logs).to include(an_object_having_attributes(level: :err, message: "whoops1"),
                               an_object_having_attributes(level: :err, message: "whoops2"))
    end

    it 'logs routing failures as debug until routing succeeds' do
      Puppet[:log_level] = 'debug'

      resolvers = [DummyResolver.new(bad_service), DummyResolver.new(good_service)]
      session = described_class.new(client, resolvers)
      session.route_to(:ca)

      expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Connection to #{uri} failed, trying next route: whoops"))
      expect(@logs).to_not include(an_object_having_attributes(level: :err))
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

    it 'routes to the service when given a puppet URL with an explicit host' do
      allow_any_instance_of(Net::HTTP).to receive(:start)

      session = described_class.new(client, [])
      url = URI("puppet://example.com:8140/:modules/:module/path/to/file")
      service = session.route_to(:fileserver, url: url)

      expect(service.url.to_s).to eq("https://example.com:8140/puppet/v3")
    end

    it 'raises a connection error if we cannot connect' do
      allow_any_instance_of(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

      session = described_class.new(client, [])
      url = URI('puppet://example.com:8140/:modules/:module/path/to/file')

      expect {
        session.route_to(:fileserver, url: url)
      }.to raise_error(Puppet::HTTP::ConnectionError,
                       %r{Request to https://example.com:8140/puppet/v3 timed out connect operation after .* seconds})
    end

    it 'resolves the route when given a generic puppet:/// URL' do
      resolvers = [DummyResolver.new(good_service)]
      session = described_class.new(client, resolvers)
      url = URI('puppet:///:modules/:module/path/to/file')
      service = session.route_to(:fileserver, url: url)

      expect(service.url).to eq(good_service.url)
    end
  end

  context 'when resolving using multiple resolvers' do
    let(:session) { client.create_session }

    it "prefers SRV records" do
      Puppet[:use_srv_records] = true
      Puppet[:server_list] = 'foo.example.com,bar.example.com,baz.example.com'
      Puppet[:ca_server] = 'caserver.example.com'

      allow_any_instance_of(Puppet::Network::Resolver).to receive(:each_srv_record).and_yield('mars.example.srv', 8140)
      service = session.route_to(:ca)

      expect(service.url).to eq(URI("https://mars.example.srv:8140/puppet-ca/v1"))
    end

    it "next prefers :ca_server when explicitly set" do
      Puppet[:use_srv_records] = true
      Puppet[:server_list] = 'foo.example.com,bar.example.com,baz.example.com'
      Puppet[:ca_server] = 'caserver.example.com'

      service = session.route_to(:ca)

      expect(service.url).to eq(URI("https://caserver.example.com:8140/puppet-ca/v1"))
    end

    it "next prefers the first successful connection from server_list" do
      Puppet[:use_srv_records] = true
      Puppet[:server_list] = 'foo.example.com,bar.example.com,baz.example.com'

      allow_any_instance_of(Puppet::Network::Resolver).to receive(:each_srv_record)
      stub_request(:get, "https://foo.example.com:8140/status/v1/simple/master").to_return(status: 500)
      stub_request(:get, "https://bar.example.com:8140/status/v1/simple/master").to_return(status: 200)

      service = session.route_to(:ca)

      expect(service.url).to eq(URI("https://bar.example.com:8140/puppet-ca/v1"))
    end

    it "fails if server_list doesn't return anything valid" do
      Puppet[:server_list] = 'foo.example.com,bar.example.com'

      allow_any_instance_of(Puppet::Network::Resolver).to receive(:each_srv_record)
      stub_request(:get, "https://foo.example.com:8140/status/v1/simple/master").to_return(status: 500)
      stub_request(:get, "https://bar.example.com:8140/status/v1/simple/master").to_return(status: 500)

      expect {
        session.route_to(:ca)
      }.to raise_error(Puppet::Error, "Could not select a functional puppet master from server_list: 'foo.example.com,bar.example.com'")
    end

    it "raises when there are no more routes" do
      allow_any_instance_of(Net::HTTP).to receive(:start).and_raise(Errno::EHOSTUNREACH)
      session = client.create_session

      expect {
        session.route_to(:ca)
      }.to raise_error(Puppet::HTTP::RouteError, 'No more routes to ca')
    end

    Puppet::HTTP::Service::SERVICE_NAMES.each do |name|
      it "resolves #{name} using server_list" do
        Puppet[:server_list] = 'apple.example.com'
        req = stub_request(:get, "https://apple.example.com:8140/status/v1/simple/master").to_return(status: 200)

        session.route_to(name)

        expect(req).to have_been_requested
      end
    end

    it 'does not use server_list to resolve the ca service when ca_server is explicitly set' do
      Puppet[:ca_server] = 'banana.example.com'

      expect(session.route_to(:ca).url.to_s).to eq("https://banana.example.com:8140/puppet-ca/v1")
    end

    it 'does not use server_list to resolve the report service when the report_server is explicitly set' do
      Puppet[:report_server] = 'cherry.example.com'

      expect(session.route_to(:report).url.to_s).to eq("https://cherry.example.com:8140/puppet/v3")
    end

    it 'resolves once for all services in a session' do
      Puppet[:server_list] = 'apple.example.com'
      req = stub_request(:get, "https://apple.example.com:8140/status/v1/simple/master").to_return(status: 200)

      Puppet::HTTP::Service::SERVICE_NAMES.each do |name|
        session.route_to(name)
      end

      expect(req).to have_been_requested
    end

    it 'resolves server_list for each new session' do
      Puppet[:server_list] = 'apple.example.com'
      req = stub_request(:get, "https://apple.example.com:8140/status/v1/simple/master").to_return(status: 200)

      client.create_session.route_to(:puppet)
      client.create_session.route_to(:puppet)

      expect(req).to have_been_requested.twice
    end
  end

  context 'when retrieving capabilities' do
    let(:session) do
      resolver = DummyResolver.new(good_service)
      described_class.new(client, [resolver])
    end

    it 'raises for unknown service names' do
      expect {
        session = described_class.new(client, [])
        session.supports?(:westbound, 'a capability')
      }.to raise_error(ArgumentError, "Unknown service westbound")
    end

    context 'locales' do
      it 'does not support locales if the cached service has not been resolved' do
        session = described_class.new(client, [])

        expect(session).to_not be_supports(:puppet, 'locales')
      end

      it "supports locales if the cached service's version is 5.3.4 or greater" do
        response = Puppet::HTTP::Response.new({'X-Puppet-Version' => '5.3.4'}, uri)

        session.route_to(:puppet)
        session.process_response(response)

        expect(session).to be_supports(:puppet, 'locales')
      end

      it "does not support locales if the cached service's version is 5.3.3" do
        response = Puppet::HTTP::Response.new({'X-Puppet-Version' => '5.3.3'}, uri)

        session.route_to(:puppet)
        session.process_response(response)

        expect(session).to_not be_supports(:puppet, 'locales')
      end

      it "does not support locales if the cached service's version is missing" do
        response = Puppet::HTTP::Response.new({}, uri)

        session.route_to(:puppet)
        session.process_response(response)

        expect(session).to_not be_supports(:puppet, 'locales')
      end
    end

    context 'json' do
      it 'does not support json if the cached service has not been resolved' do
        session = described_class.new(client, [])

        expect(session).to_not be_supports(:puppet, 'json')
      end

      it "supports json if the cached service's version is 5 or greater" do
        response = Puppet::HTTP::Response.new({'X-Puppet-Version' => '5.5.12'}, uri)

        session.route_to(:puppet)
        session.process_response(response)

        expect(session).to be_supports(:puppet, 'json')
      end

      it "does not support json if the cached service's version is less than 5.0" do
        response = Puppet::HTTP::Response.new({'X-Puppet-Version' => '4.10.1'}, uri)

        session.route_to(:puppet)
        session.process_response(response)

        expect(session).to_not be_supports(:puppet, 'json')
      end

      it "supports json if the cached service's version is missing" do
        response = Puppet::HTTP::Response.new({}, uri)

        session.route_to(:puppet)
        session.process_response(response)

        expect(session).to be_supports(:puppet, 'json')
      end
    end
  end
end
