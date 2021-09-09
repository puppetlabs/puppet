require 'spec_helper'
require 'puppet/network/http_pool'

class Puppet::Network::HttpPool::FooClient
  def initialize(host, port, options = {})
    @host = host
    @port = port
  end
  attr_reader :host, :port
end

describe Puppet::Network::HttpPool do
  include PuppetSpec::Files

  describe "when registering an http client class" do
    let(:http_impl) { Puppet::Network::HttpPool::FooClient }

    around :each do |example|
      orig_class = Puppet::Network::HttpPool.http_client_class
      begin
        example.run
      ensure
        Puppet::Network::HttpPool.http_client_class = orig_class
      end
    end

    it "returns instances of the http client class" do
      Puppet::Network::HttpPool.http_client_class = http_impl
      http = Puppet::Network::HttpPool.http_instance("me", 54321)
      expect(http).to be_an_instance_of(http_impl)
      expect(http.host).to eq('me')
      expect(http.port).to eq(54321)
    end

    it "uses the default http client" do
      expect(Puppet.runtime[:http]).to be_an_instance_of(Puppet::HTTP::Client)
    end

    it "switches to the external client implementation" do
      Puppet.runtime.clear
      Puppet::Network::HttpPool.http_client_class = http_impl

      expect(Puppet.runtime[:http]).to be_an_instance_of(Puppet::HTTP::ExternalClient)
    end

    it "always uses an explicitly registered http implementation" do
      Puppet::Network::HttpPool.http_client_class = http_impl

      new_impl = double('new_http_impl')
      Puppet.initialize_settings([], true, true, http: new_impl)

      expect(Puppet.runtime[:http]).to eq(new_impl)
    end
  end

  describe "when managing http instances" do
    it "should return an http instance created with the passed host and port" do
      http = Puppet::Network::HttpPool.http_instance("me", 54321)
      expect(http).to be_a_kind_of Puppet::Network::HTTP::Connection
      expect(http.address).to eq('me')
      expect(http.port).to    eq(54321)
    end

    it "should enable ssl on the http instance by default" do
      expect(Puppet::Network::HttpPool.http_instance("me", 54321)).to be_use_ssl
    end

    it "can set ssl using an option" do
      expect(Puppet::Network::HttpPool.http_instance("me", 54321, false)).not_to be_use_ssl
      expect(Puppet::Network::HttpPool.http_instance("me", 54321, true)).to be_use_ssl
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
        expect(Puppet).to receive(:warning).with("An ssl_context is unnecessary when connecting to 'http://me:8140' and will be ignored")

        ssl_context = Puppet::SSL::SSLContext.new
        Puppet::Network::HttpPool.connection('me', 8140, use_ssl: false, ssl_context: ssl_context)
      end
    end

    describe 'peer verification' do

      before(:each) do
        Puppet[:ssldir] = tmpdir('ssl')
        Puppet.settings.use(:main)

        Puppet[:certname] = 'signed'
        File.write(Puppet[:localcacert], cert_fixture('ca.pem'))
        File.write(Puppet[:hostcrl], crl_fixture('crl.pem'))
        File.write(Puppet[:hostcert], cert_fixture('signed.pem'))
        File.write(Puppet[:hostprivkey], key_fixture('signed-key.pem'))
      end

      it 'enables peer verification by default' do
        stub_request(:get, "https://me:54321")

        conn = Puppet::Network::HttpPool.http_instance("me", 54321, true)
        expect_any_instance_of(Net::HTTP).to receive(:start) do |http|
          expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
        end

        conn.get('/')
      end

      it 'can disable peer verification' do
        stub_request(:get, "https://me:54321")

        conn = Puppet::Network::HttpPool.http_instance("me", 54321, true, false)
        expect_any_instance_of(Net::HTTP).to receive(:start) do |http|
          expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
        end

        conn.get('/')
      end
    end

    it "should not cache http instances" do
      expect(Puppet::Network::HttpPool.http_instance("me", 54321)).
        not_to equal(Puppet::Network::HttpPool.http_instance("me", 54321))
    end
  end
end
