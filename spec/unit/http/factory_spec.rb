require 'spec_helper'
require 'puppet/http'

describe Puppet::HTTP::Factory do
  before(:all) do
    ENV['http_proxy'] = nil
    ENV['HTTP_PROXY'] = nil
  end
  before :each do
    Puppet::SSL::Key.indirection.terminus_class = :memory
    Puppet::SSL::CertificateRequest.indirection.terminus_class = :memory
  end

  let(:site) { Puppet::Network::HTTP::Site.new('https', 'www.example.com', 443) }

  def create_connection(site)
    factory = described_class.new
    factory.create_connection(site)
  end

  it 'creates a connection for the site' do
    conn = create_connection(site)

    expect(conn.use_ssl?).to be_truthy
    expect(conn.address).to eq(site.host)
    expect(conn.port).to eq(site.port)
  end

  it 'creates a connection that has not yet been started' do
    conn = create_connection(site)

    expect(conn).to_not be_started
  end

  it 'creates a connection supporting at least HTTP 1.1' do
    conn = create_connection(site)

    expect(conn.class.version_1_1? || conn.class.version_1_2?).to be_truthy
  end

  context "proxy settings" do
    let(:proxy_host) { 'myhost' }
    let(:proxy_port) { 432 }
    let(:proxy_user) { 'mo' }
    let(:proxy_pass) { 'password' }

    it "should not set a proxy if the http_proxy_host setting is 'none'" do
      Puppet[:http_proxy_host] = 'none'
      conn = create_connection(site)

      expect(conn.proxy_address).to be_nil
    end

    it 'should not set a proxy if a no_proxy env var matches the destination' do
      Puppet[:http_proxy_host] = proxy_host
      Puppet[:http_proxy_port] = proxy_port
      Puppet::Util.withenv('NO_PROXY' => site.host) do
        conn = create_connection(site)

        expect(conn.proxy_address).to be_nil
        expect(conn.proxy_port).to be_nil
      end
    end

    it 'should not set a proxy if the no_proxy setting matches the destination' do
      Puppet[:http_proxy_host] = proxy_host
      Puppet[:http_proxy_port] = proxy_port
      Puppet[:no_proxy] = site.host
      conn = create_connection(site)

      expect(conn.proxy_address).to be_nil
      expect(conn.proxy_port).to be_nil
    end

    it 'sets proxy_address' do
      Puppet[:http_proxy_host] = proxy_host
      conn = create_connection(site)

      expect(conn.proxy_address).to eq(proxy_host)
    end

    it 'sets proxy address and port' do
      Puppet[:http_proxy_host] = proxy_host
      Puppet[:http_proxy_port] = proxy_port
      conn = create_connection(site)

      expect(conn.proxy_port).to eq(proxy_port)
    end

    it 'sets proxy user and password' do
      Puppet[:http_proxy_host] = proxy_host
      Puppet[:http_proxy_port] = proxy_port
      Puppet[:http_proxy_user] = proxy_user
      Puppet[:http_proxy_password] = proxy_pass

      conn = create_connection(site)

      expect(conn.proxy_user).to eq(proxy_user)
      expect(conn.proxy_pass).to eq(proxy_pass)
    end
  end

  context 'socket timeouts' do
    it 'sets open timeout' do
      Puppet[:http_connect_timeout] = "10s"
      conn = create_connection(site)

      expect(conn.open_timeout).to eq(10)
    end

    it 'sets read timeout' do
      Puppet[:http_read_timeout] = "2m"
      conn = create_connection(site)

      expect(conn.read_timeout).to eq(120)
    end
  end

  it "disables ruby's http_keepalive_timeout" do
    conn = create_connection(site)

    expect(conn.keep_alive_timeout).to eq(2147483647)
  end

  it "disables ruby's max retry on 2.5 and up", if: RUBY_VERSION.to_f >= 2.5 do
    conn = create_connection(site)

    expect(conn.max_retries).to eq(0)
  end

  context 'source address' do
    it 'defaults to system-defined' do
      conn = create_connection(site)

      expect(conn.local_host).to be(nil)
    end

    it 'sets the local_host address' do
      Puppet[:sourceaddress] = "127.0.0.1"
      conn = create_connection(site)

      expect(conn.local_host).to eq('127.0.0.1')
    end
  end
end
