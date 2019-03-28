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

      expect(http).to receive(:get_content).with(uri.to_s, query: nil, header: nil)
        .and_raise(OpenSSL::OpenSSLError.new('certificate verify failed'))
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
      expect(http).to receive(:get_content).with(uri.to_s, query: nil, header: nil)
        .and_raise(OpenSSL::OpenSSLError.new('hostname does not match with server certificate'))
      expect { client.get(uri) }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to include("Server hostname 'foo.com' did not match")
        expect(error.message).to include('expected bar.com')
      end
    end

    it 're-raises errors it does not understand' do
      expect(http).to receive(:get_content).with(uri.to_s, query: nil, header: nil)
        .and_raise(OpenSSL::OpenSSLError.new('other ssl error'))
      expect{ client.get(uri) }.to raise_error do |error|
        expect(error).to be_a(OpenSSL::OpenSSLError)
        expect(error.message).to include('other ssl error')
      end
    end
  end

  context 'when creating a new client' do
    let(:ssl_store) { double('store') }
    let(:ssl_config) do
      double(
        'ssl config',
        :cert_store= => nil,
        :verify_callback= => nil,
        :verify_mode= => nil,
      )
    end
    let(:http) do
      double(
        'http',
        :connect_timeout= => nil,
        :receive_timeout= => nil,
        :ssl_config => ssl_config,
        :tcp_keepalive= => nil,
        :transparent_gzip_decompression= => nil,
      )
    end

    it 'initializes itself with basic defaults' do
      expect(HTTPClient).to receive(:new).and_return(http)
      # Configure connection with HTTP settings
      Puppet[:http_read_timeout] = 120
      Puppet[:http_connect_timeout] = 10
      Puppet[:http_debug] = true

      expect(http).to receive(:connect_timeout=).with(10)
      expect(http).to receive(:receive_timeout=).with(120)
      expect(http).to receive(:debug_dev=).with($stderr)

      # Configure verify mode with SSL settings
      expect(ssl_config).to receive(:cert_store=).with(ssl_store)
      Puppet[:ssl_client_ca_auth] = '/fake/path'
      Puppet[:hostcert] = '/fake/cert/path'
      expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

      Puppet::Rest::Client.new(ssl_context: Puppet::SSL::SSLContext.new(verify_peer: false, store: ssl_store))
    end

    it 'uses a given client and SSL store when provided' do
      expect(ssl_config).to receive(:cert_store=).with(ssl_store)
      Puppet::Rest::Client.new(client: http,
                               ssl_context: Puppet::SSL::SSLContext.new(verify_peer: true, store: ssl_store))
    end

    it 'configures a receive timeout when provided' do
      expect(http).to receive(:receive_timeout=).with(10)
      Puppet::Rest::Client.new(ssl_context: Puppet::SSL::SSLContext.new(verify_peer: false),
                               client: http, receive_timeout: 10)
    end
  end

  context 'when making requests' do
    let(:ssl_config) do
      double(
        'ssl config',
        :cert_store= => nil,
        :verify_callback= => nil,
        :verify_mode= => nil,
      )
    end
    let(:http) do
      double(
        'http',
        :connect_timeout= => nil,
        :receive_timeout= => nil,
        :ssl_config => ssl_config,
        :tcp_keepalive= => nil,
        :transparent_gzip_decompression= => nil,
      )
    end
    let(:client) { Puppet::Rest::Client.new(ssl_context: Puppet::SSL::SSLContext.new(verify_peer: false), client: http) }
    let(:url) { 'https://myserver.com:555/data' }

    describe "#get" do
      it 'makes a GET request given a URL, query hash, header hash, and streaming block' do
        query = { 'environment' => 'production' }
        header = { 'Accept' => 'text/plain' }
        response_string = ''
        chunk_processing = lambda { |chunk| response_string = chunk }
        expect(http).to receive(:get_content).with(url, { query: query, header: header }).and_yield('response')
        client.get(url, query: query, header: header, &chunk_processing)
        expect(response_string).to eq('response')
      end

      it 'throws an exception when the response to the GET is not OK' do
        fake_response = double('resp', :status => HTTP::Status::BAD_REQUEST)
        expect(http).to receive(:get_content).with(url, query: nil, header: nil)
            .and_raise(HTTPClient::BadResponseError.new('failed request', fake_response))
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
        expect(http).to receive(:put).with(url, { body: body, query: query, header: header })
        client.put(url, body: body, query: query, header: header)
      end

      include_examples 'connection error handling'
    end
  end
end
