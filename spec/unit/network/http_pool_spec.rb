#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http_pool'

describe Puppet::Network::HttpPool do
  before :each do
    Puppet::SSL::Key.indirection.terminus_class = :memory
    Puppet::SSL::CertificateRequest.indirection.terminus_class = :memory
  end

  describe "when managing http instances" do
    it "should return an http instance created with the passed host and port" do
      http = Puppet::Network::HttpPool.http_instance("me", 54321)
      expect(http).to be_an_instance_of Puppet::Network::HTTP::Connection
      expect(http.address).to eq('me')
      expect(http.port).to    eq(54321)
    end

    it "should support using an alternate http client implementation" do
      begin
        class FooClient
          def initialize(host, port, options = {})
            @host = host
            @port = port
          end
          attr_reader :host, :port
        end

        orig_class = Puppet::Network::HttpPool.http_client_class
        Puppet::Network::HttpPool.http_client_class = FooClient
        http = Puppet::Network::HttpPool.http_instance("me", 54321)
        expect(http).to be_an_instance_of FooClient
        expect(http.host).to eq('me')
        expect(http.port).to eq(54321)
      ensure
        Puppet::Network::HttpPool.http_client_class = orig_class
      end
    end

    it "should enable ssl on the http instance by default" do
      expect(Puppet::Network::HttpPool.http_instance("me", 54321)).to be_use_ssl
    end

    it "can set ssl using an option" do
      expect(Puppet::Network::HttpPool.http_instance("me", 54321, false)).not_to be_use_ssl
      expect(Puppet::Network::HttpPool.http_instance("me", 54321, true)).to be_use_ssl
    end

    it 'has an http_ssl_instance method' do
      expect(Puppet::Network::HttpPool.http_ssl_instance("me", 54321)).to be_use_ssl
    end

    context "when calling 'connection'" do
      it 'requires an ssl_context for HTTPS' do
        expect {
          Puppet::Network::HttpPool.connection(URI('https://me'))
        }.to raise_error(ArgumentError, %r{An ssl_context is required for HTTPS connections: https://me})
      end

      it 'creates a verifier from the context' do
        ssl_context = Puppet::SSL::SSLContext.new
        expect(
          Puppet::Network::HttpPool.connection(URI('https://me'), ssl_context: ssl_context).verifier
        ).to be_a_kind_of(Puppet::SSL::Verifier)
      end

      it 'does not use SSL for http schemes' do
        expect(Puppet::Network::HttpPool.connection(URI('http://me'))).to_not be_use_ssl
      end

      it 'warns if an ssl_context is used for http connections' do
        Puppet.expects(:warning).with('An ssl_context is unnecessary for HTTP connections and will be ignored: http://me')

        ssl_context = Puppet::SSL::SSLContext.new
        Puppet::Network::HttpPool.connection(URI('http://me'), ssl_context: ssl_context)
      end

      it 'raises when given a file scheme' do
        expect {
          Puppet::Network::HttpPool.connection(URI('file:///foo'))
        }.to raise_error(ArgumentError, "Unsupported scheme 'file'")
      end
    end

    describe 'peer verification' do
      def setup_standard_ssl_configuration
        ca_cert_file = File.expand_path('/path/to/ssl/certs/ca_cert.pem')

        Puppet[:ssl_client_ca_auth] = ca_cert_file
        Puppet::FileSystem.stubs(:exist?).with(ca_cert_file).returns(true)
      end

      def setup_standard_hostcert
        host_cert_file = File.expand_path('/path/to/ssl/certs/host_cert.pem')
        Puppet::FileSystem.stubs(:exist?).with(host_cert_file).returns(true)

        Puppet[:hostcert] = host_cert_file
      end

      def setup_standard_ssl_host
        cert = stub('cert', :content => 'real_cert')
        key  = stub('key',  :content => 'real_key')
        host = stub('host', :certificate => cert, :key => key, :ssl_store => stub('store'))

        Puppet::SSL::Host.stubs(:localhost).returns(host)
      end

      before do
        setup_standard_ssl_configuration
        setup_standard_hostcert
        setup_standard_ssl_host
      end

      it 'enables peer verification by default' do
        response = Net::HTTPOK.new('1.1', 200, 'body')
        conn = Puppet::Network::HttpPool.http_instance("me", 54321, true)
        conn.expects(:execute_request).with { |http, request| expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER) }.returns(response)
        conn.get('/')
      end

      it 'can disable peer verification' do
        response = Net::HTTPOK.new('1.1', 200, 'body')
        conn = Puppet::Network::HttpPool.http_instance("me", 54321, true, false)
        conn.expects(:execute_request).with { |http, request| expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE) }.returns(response)
        conn.get('/')
      end
    end

    it "should not cache http instances" do
      expect(Puppet::Network::HttpPool.http_instance("me", 54321)).
        not_to equal(Puppet::Network::HttpPool.http_instance("me", 54321))
    end
  end
end
