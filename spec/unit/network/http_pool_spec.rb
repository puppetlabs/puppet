#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/network/http_pool'

describe Puppet::Network::HttpPool do
  after do
    Puppet::Network::HttpPool.instance_variable_set("@ssl_host", nil)
  end

  it "should use the global SSL::Host instance to get its certificate information" do
    host = mock 'host'
    Puppet::SSL::Host.expects(:localhost).with.returns host
    Puppet::Network::HttpPool.ssl_host.should equal(host)
  end

  describe "when managing http instances" do
    before :each do
      # All of the cert stuff is tested elsewhere
      Puppet::Network::HttpPool.stubs(:cert_setup)
    end

    it "should return an http instance created with the passed host and port" do
      http = Puppet::Network::HttpPool.http_instance("me", 54321)
      http.should be_an_instance_of Net::HTTP
      http.address.should == 'me'
      http.port.should    == 54321
    end

    it "should enable ssl on the http instance" do
      Puppet::Network::HttpPool.http_instance("me", 54321).should be_use_ssl
    end

    context "proxy and timeout settings should propagate" do
      subject { Puppet::Network::HttpPool.http_instance("me", 54321) }
      before :each do
        Puppet[:http_proxy_host] = "myhost"
        Puppet[:http_proxy_port] = 432
        Puppet[:configtimeout]   = 120
      end

      its(:open_timeout)  { should == Puppet[:configtimeout] }
      its(:read_timeout)  { should == Puppet[:configtimeout] }
      its(:proxy_address) { should == Puppet[:http_proxy_host] }
      its(:proxy_port)    { should == Puppet[:http_proxy_port] }
    end

    it "should not set a proxy if the value is 'none'" do
      Puppet[:http_proxy_host] = 'none'
      Puppet::Network::HttpPool.http_instance("me", 54321).proxy_address.should be_nil
    end

    it "should not cache http instances" do
      Puppet::Network::HttpPool.http_instance("me", 54321).
        should_not equal Puppet::Network::HttpPool.http_instance("me", 54321)
    end
  end

  describe "when doing SSL setup for http instances" do
    let :http do
      http = Net::HTTP.new('localhost', 443)
      http.use_ssl = true
      http
    end

    let :store do stub('store') end

    before :each do
      Puppet[:hostcert]    = '/host/cert'
      Puppet[:localcacert] = '/local/ca/cert'

      cert  = stub 'cert', :content => 'real_cert'
      key   = stub 'key',  :content => 'real_key'
      host  = stub 'host', :certificate => cert, :key => key, :ssl_store => store
      Puppet::Network::HttpPool.stubs(:ssl_host).returns(host)
    end

    it "should do nothing if no host certificate is on disk" do
      FileTest.expects(:exist?).with(Puppet[:hostcert]).returns false
      http.expects(:cert=).never
      Puppet::Network::HttpPool.cert_setup(http)
    end

    it "should do nothing if no local certificate is on disk" do
      FileTest.expects(:exist?).with(Puppet[:hostcert]).returns true
      FileTest.expects(:exist?).with(Puppet[:localcacert]).returns false
      http.expects(:cert=).never
      Puppet::Network::HttpPool.cert_setup(http)
    end

    it "should add a certificate store from the ssl host" do
      FileTest.expects(:exist?).with(Puppet[:hostcert]).returns true
      FileTest.expects(:exist?).with(Puppet[:localcacert]).returns true
      http.expects(:cert_store=).with(store)

      Puppet::Network::HttpPool.cert_setup(http)
    end

    it "should add the client certificate" do
      FileTest.expects(:exist?).with(Puppet[:hostcert]).returns true
      FileTest.expects(:exist?).with(Puppet[:localcacert]).returns true
      http.expects(:cert=).with("real_cert")

      Puppet::Network::HttpPool.cert_setup(http)
    end

    it "should add the client key" do
      FileTest.expects(:exist?).with(Puppet[:hostcert]).returns true
      FileTest.expects(:exist?).with(Puppet[:localcacert]).returns true
      http.expects(:key=).with("real_key")

      Puppet::Network::HttpPool.cert_setup(http)
    end

    it "should set the verify mode to OpenSSL::SSL::VERIFY_PEER" do
      FileTest.expects(:exist?).with(Puppet[:hostcert]).returns true
      FileTest.expects(:exist?).with(Puppet[:localcacert]).returns true
      http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

      Puppet::Network::HttpPool.cert_setup(http)
    end

    it "should set the ca file" do
      FileTest.expects(:exist?).with(Puppet[:hostcert]).returns(true)
      FileTest.expects(:exist?).with(Puppet[:localcacert]).returns(true)

      Puppet::Network::HttpPool.cert_setup(http)
      http.ca_file.should == Puppet[:localcacert]
    end

    it "should set up certificate information when creating http instances" do
      Puppet::Network::HttpPool.expects(:cert_setup).with { |i| i.is_a?(Net::HTTP) }
      Puppet::Network::HttpPool.http_instance("one", "two")
    end
  end
end
