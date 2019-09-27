require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Resolver do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:session) { client.create_session }
  let(:uri) { URI.parse('https://www.example.com') }

  context 'when resolving using settings' do
    let(:subject) { Puppet::HTTP::Resolver::Settings.new }

    it 'yields a service based on the current ca_server and ca_port settings' do
      Puppet[:ca_server] = 'ca.example.com'
      Puppet[:ca_port] = 8141

      subject.resolve(session, :ca) do |service|
        expect(service).to be_an_instance_of(Puppet::HTTP::Service::Ca)
        expect(service.url.to_s).to eq("https://ca.example.com:8141/puppet-ca/v1")
      end
    end
  end

  context 'when resolving using SRV' do
    let(:dns) { double('dns') }
    let(:subject) { Puppet::HTTP::Resolver::SRV.new(domain: 'example.com', dns: dns) }

    def stub_srv(host, port)
      srv = Resolv::DNS::Resource::IN::SRV.new(0, 0, port, host)
      srv.instance_variable_set :@ttl, 3600

      allow(dns).to receive(:getresources).with("_x-puppet-ca._tcp.example.com", Resolv::DNS::Resource::IN::SRV).and_return([srv])
    end

    it 'yields a service based on an SRV record' do
      stub_srv('ca1.example.com', 8142)

      subject.resolve(session, :ca) do |service|
        expect(service).to be_an_instance_of(Puppet::HTTP::Service::Ca)
        expect(service.url.to_s).to eq("https://ca1.example.com:8142/puppet-ca/v1")
      end
    end
  end
end
