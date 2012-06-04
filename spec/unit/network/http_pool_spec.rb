#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-26.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/network/http_pool'

describe Puppet::Network::HttpPool do
  after do
    Puppet::Util::Cacher.expire
    Puppet::Network::HttpPool.clear_http_instances
    Puppet::Network::HttpPool.instance_variable_set("@ssl_host", nil)
  end

  it "should have keep-alive disabled" do
    Puppet::Network::HttpPool::HTTP_KEEP_ALIVE.should be_false
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
    end

    it "should not set a proxy if the value is 'none'" do
      Puppet[:http_proxy_host] = 'none'
      Puppet::Network::HttpPool.http_instance("me", 54321).proxy_address.should be_nil
    end

    describe "and http keep-alive is enabled" do
      before do
        Puppet::Network::HttpPool.stubs(:keep_alive?).returns true
      end

      it "should cache http instances" do
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).should equal(old)
      end

      it "should have a mechanism for getting a new http instance instead of the cached instance" do
        Puppet[:http_proxy_host] = "myhost"
        Puppet[:http_proxy_port] = 432
        Puppet[:configtimeout] = 120

        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321, true).should_not equal(old)
      end

      it "should close existing, open connections when requesting a new connection" do
        Puppet[:http_proxy_host] = "myhost"
        Puppet[:http_proxy_port] = 432
        Puppet[:configtimeout] = 120

        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        old.expects(:started?).returns(true)
        old.expects(:finish)
        Puppet::Network::HttpPool.http_instance("me", 54321, true)
      end

      it "should have a mechanism for clearing the http cache" do
        Puppet[:http_proxy_host] = "myhost"
        Puppet[:http_proxy_port] = 432
        Puppet[:configtimeout] = 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).should equal(old)
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.clear_http_instances
        Puppet::Network::HttpPool.http_instance("me", 54321).should_not equal(old)
      end

      it "should close open http connections when clearing the cache" do
        Puppet[:http_proxy_host] = "myhost"
        Puppet[:http_proxy_port] = 432
        Puppet[:configtimeout] = 120
        one = Puppet::Network::HttpPool.http_instance("me", 54321)
        one.expects(:started?).returns(true)
        one.expects(:finish).returns(true)
        Puppet::Network::HttpPool.clear_http_instances
      end

      it "should not close unopened http connections when clearing the cache" do
        Puppet[:http_proxy_host] = "myhost"
        Puppet[:http_proxy_port] = 432
        Puppet[:configtimeout] = 120
        one = Puppet::Network::HttpPool.http_instance("me", 54321)
        one.expects(:started?).returns(false)
        one.expects(:finish).never
        Puppet::Network::HttpPool.clear_http_instances
      end
    end

    describe "and http keep-alive is disabled" do
      before do
        Puppet::Network::HttpPool.stubs(:keep_alive?).returns false
      end

      it "should not cache http instances" do
        Puppet[:http_proxy_host] = "myhost"
        Puppet[:http_proxy_port] = 432
        Puppet[:configtimeout] = 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).should_not equal(old)
      end
    end

    after do
      Puppet::Network::HttpPool.clear_http_instances
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

    shared_examples "HTTPS setup without all certificates" do
      subject { Puppet::Network::HttpPool.cert_setup(http); http }

      it                { should be_use_ssl }
      its(:cert)        { should be_nil }
      its(:ca_file)     { should be_nil }
      its(:key)         { should be_nil }
      its(:verify_mode) { should == OpenSSL::SSL::VERIFY_NONE }
    end

    context "with neither a host cert or a local CA cert" do
      before :each do
        FileTest.stubs(:exist?).with(Puppet[:hostcert]).returns(false)
        FileTest.stubs(:exist?).with(Puppet[:localcacert]).returns(false)
      end

      include_examples "HTTPS setup without all certificates"
    end

    context "with there is no host certificate" do
      before :each do
        FileTest.stubs(:exist?).with(Puppet[:hostcert]).returns(false)
        FileTest.stubs(:exist?).with(Puppet[:localcacert]).returns(true)
      end

      include_examples "HTTPS setup without all certificates"
    end

    context "with there is no local CA certificate" do
      before :each do
        FileTest.stubs(:exist?).with(Puppet[:hostcert]).returns(true)
        FileTest.stubs(:exist?).with(Puppet[:localcacert]).returns(false)
      end

      include_examples "HTTPS setup without all certificates"
    end

    context "with both the host and CA cert" do
      subject { Puppet::Network::HttpPool.cert_setup(http); http }

      before :each do
        FileTest.expects(:exist?).with(Puppet[:hostcert]).returns(true)
        FileTest.expects(:exist?).with(Puppet[:localcacert]).returns(true)
      end

      it                { should be_use_ssl }
      its(:cert_store)  { should equal store }
      its(:cert)        { should == "real_cert" }
      its(:key)         { should == "real_key" }
      its(:verify_mode) { should == OpenSSL::SSL::VERIFY_PEER }
      its(:ca_file)     { should == Puppet[:localcacert] }
    end

    it "should set up certificate information when creating http instances" do
      Puppet::Network::HttpPool.expects(:cert_setup).with do |http|
        http.should be_an_instance_of Net::HTTP
        http.address.should == "one"
        http.port.should == 2
      end

      Puppet::Network::HttpPool.http_instance("one", 2)
    end
  end
end
