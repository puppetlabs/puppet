require 'spec_helper'

require 'puppet/rest/client'
require 'puppet_spec/validators'
require 'puppet_spec/ssl'

describe Puppet::Rest::Client do
  # Follows closely with spec/unit/network/http/connection_spec's
  # 'ssl verifier' shared context
  shared_examples 'connection error handling' do
    let(:uri) { URI.parse('https://foo.com/blah') }

    it 'provides a meaningful error message when cert validation fails' do
      client.instance_variable_set(:@verifier,
                                   ConstantErrorValidator.new(
                                     error_string: 'foo'))

      http.expects(:get_content).with(uri.to_s, query: nil, header: nil)
        .raises(OpenSSL::OpenSSLError.new('certificate verify failed'))
      expect{ client.get(uri) }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to include('foo')
      end
    end

    it 'provides valuable error message when cert names do not match' do
      cert = PuppetSpec::SSL.self_signed_ca(PuppetSpec::SSL.create_private_key,
                                              '/CN=bar.com')
      client.instance_variable_set(:@verifier,
                                   ConstantErrorValidator.new(
                                     peer_certs: [cert]))
      http.expects(:get_content).with(uri.to_s, query: nil, header: nil)
        .raises(OpenSSL::OpenSSLError.new('hostname does not match with server certificate'))
      expect { client.get(uri) }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to include("Server hostname 'foo.com' did not match")
        expect(error.message).to include('expected bar.com')
      end
    end

    it 're-raises errors it does not understand' do
      http.expects(:get_content).with(uri.to_s, query: nil, header: nil)
        .raises(OpenSSL::OpenSSLError.new('other ssl error'))
      expect{ client.get(uri) }.to raise_error do |error|
        expect(error).to be_a(OpenSSL::OpenSSLError)
        expect(error.message).to include('other ssl error')
      end

    end
  end

  context 'when creating a new client' do
    let(:ssl_store) { mock('store') }
    let(:ssl_config) { stub_everything('ssl config') }
    let(:http) { stub_everything('http', :ssl_config => ssl_config) }

    it 'initializes itself with basic defaults' do
      HTTPClient.expects(:new).returns(http)
      # Configure connection with HTTP settings
      Puppet[:http_read_timeout] = 120
      Puppet[:http_connect_timeout] = 10
      Puppet[:http_debug] = true

      http.expects(:connect_timeout=).with(10)
      http.expects(:receive_timeout=).with(120)
      http.expects(:debug_dev=).with($stderr)

      # Configure verify mode with SSL settings
      ssl_config.expects(:cert_store=).with(ssl_store)
      Puppet[:ssl_client_ca_auth] = '/fake/path'
      Puppet[:hostcert] = '/fake/cert/path'
      ssl_config.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      Puppet::Rest::Client.new(ssl_context: Puppet::SSL::SSLContext.new(verify_peer: false, store: ssl_store))
    end

    it 'uses a given client and SSL store when provided' do
      ssl_config.expects(:cert_store=).with(ssl_store)
      Puppet::Rest::Client.new(client: http,
                               ssl_context: Puppet::SSL::SSLContext.new(verify_peer: true, store: ssl_store))
    end

    it 'configures a receive timeout when provided' do
      http.expects(:receive_timeout=).with(10)
      Puppet::Rest::Client.new(ssl_context: Puppet::SSL::SSLContext.new(verify_peer: false),
                               client: http, receive_timeout: 10)
    end
  end

  context 'when making requests' do
    let(:ssl_config) { stub_everything('ssl config') }
    let(:http) { stub_everything('http', :ssl_config => ssl_config) }
    let(:client) { Puppet::Rest::Client.new(ssl_context: Puppet::SSL::SSLContext.new(verify_peer: false), client: http) }
    let(:url) { 'https://myserver.com:555/data' }

    describe "#get" do
      it 'makes a GET request given a URL, query hash, header hash, and streaming block' do
        query = { 'environment' => 'production' }
        header = { 'Accept' => 'text/plain' }
        response_string = ''
        chunk_processing = lambda { |chunk| response_string = chunk }
        http.expects(:get_content).with(url, { query: query, header: header }).yields('response')
        client.get(url, query: query, header: header, &chunk_processing)
        expect(response_string).to eq('response')
      end

      it 'throws an exception when the response to the GET is not OK' do
        fake_response = mock('resp', :status => HTTP::Status::BAD_REQUEST)
        http.expects(:get_content).with(url, query: nil, header: nil)
            .raises(HTTPClient::BadResponseError.new('failed request', fake_response))
        expect { client.get(url) }.to raise_error do |error|
          expect(error.message).to eq('failed request')
          expect(error.response).to be_a(Puppet::Rest::Response)
          expect(error.response.status_code).to eq(400)
        end
      end

      include_examples 'connection error handling'
    end

    describe "#put" do
      it 'makes a PUT request given a URL, string body, query hash, and header hash' do
        body = 'send to server'
        query = { 'environment' => 'production' }
        header = { 'Accept' => 'text/plain' }
        http.expects(:put).with(url, { body: body, query: query, header: header })
        client.put(url, body: body, query: query, header: header)
      end

      include_examples 'connection error handling'
    end
  end
end
