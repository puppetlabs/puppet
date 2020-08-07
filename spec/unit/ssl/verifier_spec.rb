require 'spec_helper'

describe Puppet::SSL::Verifier do
  let(:options) { {} }
  let(:ssl_context) { Puppet::SSL::SSLContext.new(options) }
  let(:host) { 'example.com' }
  let(:http) { Net::HTTP.new(host) }
  let(:verifier) { described_class.new(host, ssl_context) }

  context '#reusable?' do
    it 'Verifiers with the same ssl_context are reusable' do
      expect(verifier).to be_reusable(described_class.new(host, ssl_context))
    end

    it 'Verifiers with different ssl_contexts are not reusable' do
      expect(verifier).to_not be_reusable(described_class.new(host, Puppet::SSL::SSLContext.new))
    end
  end

  context '#setup_connection' do
    it 'copies parameters from the ssl_context to the connection' do
      store = double('store')
      options.merge!(store: store)
      verifier.setup_connection(http)

      expect(http.cert_store).to eq(store)
    end

    it 'defaults to VERIFY_PEER' do
      expect(http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

      verifier.setup_connection(http)
    end

    it 'only uses VERIFY_NONE if explicitly disabled' do
      options.merge!(verify_peer: false)

      expect(http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      verifier.setup_connection(http)
    end

    it 'registers a verify callback' do
      verifier.setup_connection(http)

      expect(http.verify_callback).to eq(verifier)
    end
  end

  context '#handle_connection_error' do
    let(:peer_cert) { cert_fixture('127.0.0.1.pem') }
    let(:chain) { [peer_cert] }
    let(:ssl_error) { OpenSSL::SSL::SSLError.new("certificate verify failed") }

    it "raises a verification error for a CA cert" do
      store_context = double('store_context', current_cert: peer_cert, chain: [peer_cert], error: OpenSSL::X509::V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY, error_string: "unable to get local issuer certificate")
      verifier.call(false, store_context)

      expect {
        verifier.handle_connection_error(http, ssl_error)
      }.to raise_error(Puppet::SSL::CertVerifyError, "certificate verify failed [unable to get local issuer certificate for CN=127.0.0.1]")
    end

    it "raises a verification error for the server cert" do
      store_context = double('store_context', current_cert: peer_cert, chain: chain, error: OpenSSL::X509::V_ERR_CERT_REJECTED, error_string: "certificate rejected")
      verifier.call(false, store_context)

      expect {
        verifier.handle_connection_error(http, ssl_error)
      }.to raise_error(Puppet::SSL::CertVerifyError, "certificate verify failed [certificate rejected for CN=127.0.0.1]")
    end

    it "raises cert mismatch error on ruby < 2.4" do
      expect(http).to receive(:peer_cert).and_return(peer_cert)

      store_context = double('store_context')
      verifier.call(true, store_context)

      ssl_error = OpenSSL::SSL::SSLError.new("hostname 'example'com' does not match the server certificate")

      expect {
        verifier.handle_connection_error(http, ssl_error)
      }.to raise_error(Puppet::Error, "Server hostname 'example.com' did not match server certificate; expected one of 127.0.0.1, DNS:127.0.0.1, DNS:127.0.0.2")
    end

    it "raises cert mismatch error on ruby >= 2.4" do
      store_context = double('store_context', current_cert: peer_cert, chain: chain, error: OpenSSL::X509::V_OK, error_string: "ok")
      verifier.call(false, store_context)

      expect {
        verifier.handle_connection_error(http, ssl_error)
      }.to raise_error(Puppet::Error, "Server hostname 'example.com' did not match server certificate; expected one of 127.0.0.1, DNS:127.0.0.1, DNS:127.0.0.2")
    end

    it 're-raises other ssl connection errors' do
      err = OpenSSL::SSL::SSLError.new("This version of OpenSSL does not support FIPS mode")
      expect {
        verifier.handle_connection_error(http, err)
      }.to raise_error(err)
    end
  end
end
