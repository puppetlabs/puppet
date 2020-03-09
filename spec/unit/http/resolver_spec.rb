require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Resolver do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:session) { client.create_session }
  let(:uri) { URI.parse('https://www.example.com') }

  context 'when resolving using settings' do
    let(:subject) { Puppet::HTTP::Resolver::Settings.new(client) }

    it 'returns a service based on the current ca_server and ca_port settings' do
      Puppet[:ca_server] = 'ca.example.com'
      Puppet[:ca_port] = 8141

      service = subject.resolve(session, :ca)
      expect(service).to be_an_instance_of(Puppet::HTTP::Service::Ca)
      expect(service.url.to_s).to eq("https://ca.example.com:8141/puppet-ca/v1")
    end
  end

  context 'when resolving using server_list' do
    let(:subject) { Puppet::HTTP::Resolver::ServerList.new(client, server_list_setting: Puppet.settings.setting(:server_list), default_port: 8142, services: Puppet::HTTP::Service::SERVICE_NAMES) }

    before :each do
      Puppet[:server_list] = 'ca.example.com:8141,apple.example.com'
    end

    it 'returns a service based on the current server_list setting' do
      stub_request(:get, "https://ca.example.com:8141/status/v1/simple/master").to_return(status: 200)

      service = subject.resolve(session, :ca)
      expect(service).to be_an_instance_of(Puppet::HTTP::Service::Ca)
      expect(service.url.to_s).to eq("https://ca.example.com:8141/puppet-ca/v1")
    end

    it 'returns a service based on the current server_list setting if the server returns any success codes' do
      stub_request(:get, "https://ca.example.com:8141/status/v1/simple/master").to_return(status: 202)

      service = subject.resolve(session, :ca)
      expect(service).to be_an_instance_of(Puppet::HTTP::Service::Ca)
      expect(service.url.to_s).to eq("https://ca.example.com:8141/puppet-ca/v1")
    end

    it 'logs unsuccessful HTTP 500 responses' do
      Puppet[:log_level] = "debug"

      stub_request(:get, "https://ca.example.com:8141/status/v1/simple/master").to_return(status: [500, 'Internal Server Error'])
      stub_request(:get, "https://apple.example.com:8142/status/v1/simple/master").to_return(status: 200)

      subject.resolve(session, :ca)

      expect(@logs.map(&:message)).to include(/Puppet server ca.example.com:8141 is unavailable: 500 Internal Server Error/)
    end

    it 'fails if no servers in server_list are accessible' do
      stub_request(:get, "https://ca.example.com:8141/status/v1/simple/master").to_return(status: 503)
      stub_request(:get, "https://apple.example.com:8142/status/v1/simple/master").to_return(status: 503)

      expect { subject.resolve(session, :ca) }.to raise_error(Puppet::Error, /^Could not select a functional puppet master from server_list:/)
    end

    it 'cycles through server_list until a valid server is found' do
      stub_request(:get, "https://ca.example.com:8141/status/v1/simple/master").to_return(status: 503)
      stub_request(:get, "https://apple.example.com:8142/status/v1/simple/master").to_return(status: 200)

      service = subject.resolve(session, :ca)
      expect(service).to be_an_instance_of(Puppet::HTTP::Service::Ca)
      expect(service.url.to_s).to eq("https://apple.example.com:8142/puppet-ca/v1")
    end

    it 'resolves once per session' do
      failed = stub_request(:get, "https://ca.example.com:8141/status/v1/simple/master").to_return(status: 503)
      passed = stub_request(:get, "https://apple.example.com:8142/status/v1/simple/master").to_return(status: 200)

      service = subject.resolve(session, :puppet)
      expect(service.url.to_s).to eq("https://apple.example.com:8142/puppet/v3")

      service = subject.resolve(session, :fileserver)
      expect(service.url.to_s).to eq("https://apple.example.com:8142/puppet/v3")

      service = subject.resolve(session, :report)
      expect(service.url.to_s).to eq("https://apple.example.com:8142/puppet/v3")

      expect(failed).to have_been_requested
      expect(passed).to have_been_requested
    end
  end

  context 'when resolving using SRV' do
    let(:dns) { double('dns') }
    let(:subject) { Puppet::HTTP::Resolver::SRV.new(client, domain: 'example.com', dns: dns) }

    def stub_srv(host, port)
      srv = Resolv::DNS::Resource::IN::SRV.new(0, 0, port, host)
      srv.instance_variable_set :@ttl, 3600

      allow(dns).to receive(:getresources).with("_x-puppet-ca._tcp.example.com", Resolv::DNS::Resource::IN::SRV).and_return([srv])
    end

    it 'returns a service based on an SRV record' do
      stub_srv('ca1.example.com', 8142)

      service = subject.resolve(session, :ca)
      expect(service).to be_an_instance_of(Puppet::HTTP::Service::Ca)
      expect(service.url.to_s).to eq("https://ca1.example.com:8142/puppet-ca/v1")
    end
  end
end
