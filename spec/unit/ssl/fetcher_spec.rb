require 'spec_helper'
require 'webmock/rspec'

require 'puppet/ssl'

describe Puppet::SSL::Fetcher do
  let(:ssl_context) { Puppet::SSL::SSLContext.new }
  let(:fetcher) { described_class.new(ssl_context) }

  before(:each) do
    WebMock.disable_net_connect!

    Net::HTTP.any_instance.stubs(:start)
    Net::HTTP.any_instance.stubs(:finish)
  end

  context 'when fetching cacerts' do
    let(:cacerts) { 'PEM' }

    it "fetches the 'ca' certificate" do
      stub_request(:get, %r{puppet-ca/v1/certificate/ca}).to_return(status: 200, body: cacerts)

      expect(fetcher.fetch_cacerts).to eq(cacerts)
    end

    it 'raises if the server returns 404' do
      stub_request(:get, %r{puppet-ca/v1/certificate/ca}).to_return(status: 404)

      expect {
        fetcher.fetch_cacerts
      }.to raise_error(Puppet::Error, /CA certificate is missing from the server/)
    end

    it 'raises if there is a different error' do
      stub_request(:get, %r{puppet-ca/v1/certificate/ca}).to_return(status: [500, 'Internal Server Error'])

      expect {
        fetcher.fetch_cacerts
      }.to raise_error(Puppet::Error, /Could not download CA certificate: Internal Server Error/)
    end
  end

  context 'when fetching crls' do
    let(:crls) { 'PEM' }

    it "fetches the 'ca' CRL" do
      stub_request(:get, %r{puppet-ca/v1/certificate_revocation_list/ca}).to_return(status: 200, body: crls)

      expect(fetcher.fetch_crls).to eq(crls)
    end

    it 'raises if the server returns 404' do
      stub_request(:get, %r{puppet-ca/v1/certificate_revocation_list/ca}).to_return(status: 404)

      expect {
        fetcher.fetch_crls
      }.to raise_error(Puppet::Error, /CRL is missing from the server/)
    end

    it 'raises if there is a networking error' do
      stub_request(:get, %r{puppet-ca/v1/certificate_revocation_list/ca}).to_return(status: [500, 'Internal Server Error'])

      expect {
        fetcher.fetch_crls
      }.to raise_error(Puppet::Error, /Could not download CRLs: Internal Server Error/)
    end
  end
end
