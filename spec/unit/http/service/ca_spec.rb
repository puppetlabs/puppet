require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Service::Ca do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:session) { Puppet::HTTP::Session.new(client, []) }
  let(:subject) { client.create_session.route_to(:ca) }

  before :each do
    Puppet[:ca_server] = 'www.example.com'
    Puppet[:ca_port] = 443
  end

  context 'when making requests' do
    let(:uri) {"https://www.example.com:443/puppet-ca/v1/certificate/ca"}

    it 'includes default HTTP headers' do
      stub_request(:get, uri).with do |request|
        expect(request.headers).to include({'X-Puppet-Version' => /./, 'User-Agent' => /./})
        expect(request.headers).to_not include('X-Puppet-Profiling')
      end

      subject.get_certificate('ca')
    end


    it 'includes the X-Puppet-Profiling header when Puppet[:profile] is true' do
      stub_request(:get, uri).with(headers: {'X-Puppet-Version' => /./, 'User-Agent' => /./, 'X-Puppet-Profiling' => 'true'})

      Puppet[:profile] = true

      subject.get_certificate('ca')
    end
  end

  context 'when routing to the CA service' do
    let(:cert) { cert_fixture('ca.pem') }
    let(:pem) { cert.to_pem }

    it 'defaults the server and port based on settings' do
      Puppet[:ca_server] = 'ca.example.com'
      Puppet[:ca_port] = 8141

      stub_request(:get, "https://ca.example.com:8141/puppet-ca/v1/certificate/ca").to_return(body: pem)

      subject.get_certificate('ca')
    end

    it 'fallbacks to server and masterport' do
      Puppet[:ca_server] = nil
      Puppet[:ca_port] = nil
      Puppet[:server] = 'ca2.example.com'
      Puppet[:masterport] = 8142

      stub_request(:get, "https://ca2.example.com:8142/puppet-ca/v1/certificate/ca").to_return(body: pem)

      subject.get_certificate('ca')
    end
  end

  context 'when getting certificates' do
    let(:cert) { cert_fixture('ca.pem') }
    let(:pem) { cert.to_pem }
    let(:url) { "https://www.example.com/puppet-ca/v1/certificate/ca" }

    it 'gets a certificate from the "certificate" endpoint' do
      stub_request(:get, url).to_return(body: pem)

      expect(subject.get_certificate('ca')).to eq(pem)
    end

    it 'accepts text/plain responses' do
      stub_request(:get, url).with(headers: {'Accept' => 'text/plain'})

      subject.get_certificate('ca')
    end

    it 'raises a response error if unsuccessful' do
      stub_request(:get, url).to_return(status: [404, 'Not Found'])

      expect {
        subject.get_certificate('ca')
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq("Not Found")
        expect(err.response.code).to eq(404)
      end
    end
  end

  context 'when getting CRLs' do
    let(:crl) { crl_fixture('crl.pem') }
    let(:pem) { crl.to_pem }
    let(:url) { "https://www.example.com/puppet-ca/v1/certificate_revocation_list/ca" }

    it 'gets a CRL from "certificate_revocation_list" endpoint' do
      stub_request(:get, url).to_return(body: pem)

      expect(subject.get_certificate_revocation_list).to eq(pem)
    end

    it 'accepts text/plain responses' do
      stub_request(:get, url).with(headers: {'Accept' => 'text/plain'})

      subject.get_certificate_revocation_list
    end

    it 'raises a response error if unsuccessful' do
      stub_request(:get, url).to_return(status: [404, 'Not Found'])

      expect {
        subject.get_certificate_revocation_list
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq("Not Found")
        expect(err.response.code).to eq(404)
      end
    end

    it 'raises a 304 response error if it is unmodified' do
      stub_request(:get, url).to_return(status: [304, 'Not Modified'])

      expect {
        subject.get_certificate_revocation_list(if_modified_since: Time.now)
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq("Not Modified")
        expect(err.response.code).to eq(304)
      end
    end
  end

  context 'when submitting a CSR' do
    let(:request) { request_fixture('request.pem') }
    let(:pem) { request.to_pem }
    let(:url) { "https://www.example.com/puppet-ca/v1/certificate_request/infinity" }

    it 'submits a CSR to the "certificate_request" endpoint' do
      stub_request(:put, url).with(body: pem, headers: { 'Content-Type' => 'text/plain' })

      subject.put_certificate_request('infinity', request)
    end

    it 'raises response error if unsuccessful' do
      stub_request(:put, url).to_return(status: [400, 'Bad Request'])

      expect {
        subject.put_certificate_request('infinity', request)
      }.to raise_error do |err|
        expect(err).to be_an_instance_of(Puppet::HTTP::ResponseError)
        expect(err.message).to eq('Bad Request')
        expect(err.response.code).to eq(400)
      end
    end
  end
end
