#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::SSL::Verifier do
  let(:options) { {} }
  let(:ssl_context) { Puppet::SSL::SSLContext.new(options) }
  let(:host) { 'example.com' }
  let(:http) { Net::HTTP.new(host) }
  let(:verifier) { described_class.new(ssl_context) }

  context '#setup_connection' do
    it 'copies parameters from the ssl_context to the connection' do
      store = stub('store')
      options.merge!(store: store)
      verifier.setup_connection(http)

      expect(http.cert_store).to eq(store)
    end

    it 'defaults to VERIFY_PEER' do
      http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

      verifier.setup_connection(http)
    end

    it 'only uses VERIFY_NONE if explicitly disabled' do
      options.merge!(verify_peer: false)

      http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      verifier.setup_connection(http)
    end

    it 'registers a verify callback' do
      verifier.setup_connection(http)

      expect(http.verify_callback).to eq(verifier)
    end
  end

  context '#handle_connection_error' do
    let(:peer_cert) { OpenSSL::X509::Certificate.new(File.read(my_fixture('foobarbaz.pem'))) }

    # See https://github.com/ruby/ruby/blob/v2_5_3/ext/openssl/lib/openssl/ssl.rb#L394
    let(:ssl_error) { OpenSSL::SSL::SSLError.new("hostname \"foo\" does not match the server certificate") }

    it "raises cert mismatch error if 'post_connection_check' detects mismatch on ruby < 2.4" do
      http.expects(:peer_cert).returns(peer_cert)

      expect {
        verifier.handle_connection_error(http, ssl_error)
      }.to raise_error(Puppet::Error, "Server hostname 'example.com' did not match server certificate; expected one of foo, DNS:foo, DNS:bar, DNS:baz")
    end

    it "raises cert mismatch error if 'connect' detects mismatch on ruby 2.4 and up" do
      store_context = stub('store_context', current_cert: peer_cert, error: OpenSSL::X509::V_ERR_CERT_REJECTED, error_string: "certificate rejected")
      verifier.call(false, store_context)

      expect {
        verifier.handle_connection_error(http, ssl_error)
      }.to raise_error(Puppet::Error, "Server hostname 'example.com' did not match server certificate; expected one of foo, DNS:foo, DNS:bar, DNS:baz")
    end

    it 'raises the first verification error' do
      store_context = stub('store_context', current_cert: peer_cert, error: OpenSSL::X509::V_ERR_CERT_HAS_EXPIRED, error_string: "certificate expired")
      verifier.call(false, store_context)
      store_context = stub('store_context', current_cert: peer_cert, error: OpenSSL::X509::V_ERR_CERT_REJECTED, error_string: "certificate rejected")
      verifier.call(false, store_context)

      http = Net::HTTP.new('foo')
      expect {
        verifier.handle_connection_error(http, OpenSSL::SSL::SSLError.new("certificate verification failed"))
      }.to raise_error do |err|
        expect(err).to be_a(Puppet::SSL::CertVerifyError)
        expect(err.code).to eq(OpenSSL::X509::V_ERR_CERT_HAS_EXPIRED)
        expect(err.cert).to eq(peer_cert)
      end
    end

    it 'otherwise it re-raises the ssl error' do
      err = OpenSSL::SSL::SSLError.new("This version of OpenSSL does not support FIPS mode")
      expect {
        verifier.handle_connection_error(http, err)
      }.to raise_error(err)
    end
  end
end
