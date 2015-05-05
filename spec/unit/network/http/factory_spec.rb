#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http'
require 'puppet/util/http_proxy'

describe Puppet::Network::HTTP::Factory do
  before :each do
    Puppet::SSL::Key.indirection.terminus_class = :memory
    Puppet::SSL::CertificateRequest.indirection.terminus_class = :memory
  end

  let(:site) { Puppet::Network::HTTP::Site.new('https', 'www.example.com', 443) }
  def create_connection(site)
    factory = Puppet::Network::HTTP::Factory.new

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

    expect(any_of(conn.class.version_1_1?, conn.class.version_1_1?)).to be_truthy
  end

  context "proxy settings" do
    let(:proxy_host) { 'myhost' }
    let(:proxy_port) { 432 }

    it "should not set a proxy if the value is 'none'" do
      Puppet[:http_proxy_host] = 'none'
      Puppet::Util::HttpProxy.expects(:no_proxy?).returns false
      conn = create_connection(site)

      expect(conn.proxy_address).to be_nil
    end

    it 'should not set a proxy if a no_proxy env var matches the destination' do
      Puppet[:http_proxy_host] = proxy_host
      Puppet[:http_proxy_port] = proxy_port
      Puppet::Util::HttpProxy.expects(:no_proxy?).returns true
      conn = create_connection(site)

      expect(conn.proxy_address).to be_nil
      expect(conn.proxy_port).to be_nil
    end

    it 'sets proxy_address' do
      Puppet[:http_proxy_host] = proxy_host
      Puppet::Util::HttpProxy.expects(:no_proxy?).returns false
      conn = create_connection(site)

      expect(conn.proxy_address).to eq(proxy_host)
    end

    it 'sets proxy address and port' do
      Puppet[:http_proxy_host] = proxy_host
      Puppet[:http_proxy_port] = proxy_port
      Puppet::Util::HttpProxy.expects(:no_proxy?).returns false
      conn = create_connection(site)

      expect(conn.proxy_port).to eq(proxy_port)
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
  end
end
