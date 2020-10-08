require 'spec_helper'
require 'puppet/http'

describe Puppet::HTTP::Service::Puppetserver do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:subject) { client.create_session.route_to(:puppetserver) }

  before :each do
    Puppet[:server] = 'puppetserver.example.com'
  end

  context 'when making requests' do
    it 'includes default HTTP headers' do
      stub_request(:get, "https://puppetserver.example.com:8140/status/v1/simple/master").with do |request|
        expect(request.headers).to include({'X-Puppet-Version' => /./, 'User-Agent' => /./})
        expect(request.headers).to_not include('X-Puppet-Profiling')
      end.to_return(body: "running", headers: {'Content-Type' => 'text/plain;charset=utf-8'})

      subject.get_simple_status
    end

    it 'includes extra headers' do
      Puppet[:http_extra_headers] = 'region:us-west'

      stub_request(:get, "https://puppetserver.example.com:8140/status/v1/simple/master")
        .with(headers: {'Region' => 'us-west'})
        .to_return(body: "running", headers: {'Content-Type' => 'text/plain;charset=utf-8'})

      subject.get_simple_status
    end
  end

  context 'when routing to the puppetserver service' do
    it 'defaults the server and port based on settings' do
      Puppet[:server] = 'compiler2.example.com'
      Puppet[:masterport] = 8141

      stub_request(:get, "https://compiler2.example.com:8141/status/v1/simple/master")
        .to_return(body: "running", headers: {'Content-Type' => 'text/plain;charset=utf-8'})

      subject.get_simple_status
    end
  end

  context 'when getting puppetserver status' do
    let(:url) { "https://puppetserver.example.com:8140/status/v1/simple/master" }

    it 'returns the request response and status' do
      stub_request(:get, url)
        .to_return(body: "running", headers: {'Content-Type' => 'text/plain;charset=utf-8'})

      resp, status = subject.get_simple_status
      expect(resp).to be_a(Puppet::HTTP::Response)
      expect(status).to eq('running')
    end

    it 'raises a response error if unsuccessful' do
      stub_request(:get, url).to_return(status: [500, 'Internal Server Error'])

      expect {
        subject.get_simple_status
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq("Internal Server Error")
        expect(err.response.code).to eq(500)
      end
    end

    it 'accepts an ssl context' do
      stub_request(:get, url)
        .to_return(body: "running", headers: {'Content-Type' => 'text/plain;charset=utf-8'})

      other_ctx = Puppet::SSL::SSLContext.new
      expect(client).to receive(:connect).with(URI(url), options: {ssl_context: other_ctx}).and_call_original

      session = client.create_session
      service = Puppet::HTTP::Service.create_service(client, session, :puppetserver, 'puppetserver.example.com', 8140)
      service.get_simple_status(ssl_context: other_ctx)
    end
  end

  context 'when /status/v1/simple/master returns not found' do
    it 'calls /status/v1/simple/server' do
      stub_request(:get, "https://puppetserver.example.com:8140/status/v1/simple/master")
        .to_return(status: [404, 'not found: server'])

      stub_request(:get, "https://puppetserver.example.com:8140/status/v1/simple/server")
        .to_return(body: "running", headers: {'Content-Type' => 'text/plain;charset=utf-8'})

      resp, status = subject.get_simple_status
      expect(resp).to be_a(Puppet::HTTP::Response)
      expect(status).to eq('running')
    end

    it 'raises a response error if fallback is unsuccessful' do
      stub_request(:get, "https://puppetserver.example.com:8140/status/v1/simple/master")
        .to_return(status: [404, 'not found: server'])

      stub_request(:get, "https://puppetserver.example.com:8140/status/v1/simple/server")
        .to_return(status: [404, 'not found: master'])

      expect {
        subject.get_simple_status
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq('not found: master')
        expect(err.response.code).to eq(404)
      end
    end
  end
end
