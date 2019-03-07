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
      it 'requires an ssl_context' do
        expect {
          Puppet::Network::HttpPool.connection('me', 8140)
        }.to raise_error(ArgumentError, "An ssl_context is required when connecting to 'https://me:8140'")
      end

      it 'creates a verifier from the context' do
        ssl_context = Puppet::SSL::SSLContext.new
        expect(
          Puppet::Network::HttpPool.connection('me', 8140, ssl_context: ssl_context).verifier
        ).to be_a_kind_of(Puppet::SSL::Verifier)
      end

      it 'does not use SSL when specified' do
        expect(Puppet::Network::HttpPool.connection('me', 8140, use_ssl: false)).to_not be_use_ssl
      end

      it 'defaults to SSL' do
        ssl_context = Puppet::SSL::SSLContext.new
        conn = Puppet::Network::HttpPool.connection('me', 8140, ssl_context: ssl_context)
        expect(conn).to be_use_ssl
      end

      it 'warns if an ssl_context is used for an http connection' do
        Puppet.expects(:warning).with("An ssl_context is unnecessary when connecting to 'http://me:8140' and will be ignored")

        ssl_context = Puppet::SSL::SSLContext.new
        Puppet::Network::HttpPool.connection('me', 8140, use_ssl: false, ssl_context: ssl_context)
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
