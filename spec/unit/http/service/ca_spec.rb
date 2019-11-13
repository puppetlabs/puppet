require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Service::Ca do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:client) { Puppet::HTTP::Client.new(ssl_context: ssl_context) }
  let(:base_url) { URI.parse('https://www.example.com') }
  let(:subject) { described_class.new(client, base_url) }

  context 'when getting certificates' do
    let(:cert) { cert_fixture('ca.pem') }
    let(:pem) { cert.to_pem }
    let(:url) { "https://www.example.com/certificate/ca" }

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
    let(:url) { "https://www.example.com/certificate_revocation_list/ca" }

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
    let(:url) { "https://www.example.com/certificate_request/infinity" }

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
