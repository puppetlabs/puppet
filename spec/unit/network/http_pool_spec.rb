#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-11-26.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'
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
    def stub_settings(settings)
      settings.each do |param, value|
        Puppet.settings.stubs(:value).with(param).returns(value)
      end
    end

    before do
      # All of the cert stuff is tested elsewhere
      Puppet::Network::HttpPool.stubs(:cert_setup)
    end

    it "should return an http instance created with the passed host and port" do
      http = stub 'http', :use_ssl= => nil, :read_timeout= => nil, :open_timeout= => nil, :started? => false
      Net::HTTP.expects(:new).with("me", 54321, nil, nil).returns(http)
      Puppet::Network::HttpPool.http_instance("me", 54321).should equal(http)
    end

    it "should enable ssl on the http instance" do
      Puppet::Network::HttpPool.http_instance("me", 54321).instance_variable_get("@use_ssl").should be_true
    end

    it "should set the read timeout" do
      Puppet::Network::HttpPool.http_instance("me", 54321).read_timeout.should == 120
    end

    it "should set the open timeout" do
      Puppet::Network::HttpPool.http_instance("me", 54321).open_timeout.should == 120
    end

    it "should create the http instance with the proxy host and port set if the http_proxy is not set to 'none'" do
      stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
      Puppet::Network::HttpPool.http_instance("me", 54321).open_timeout.should == 120
    end

    describe "and http keep-alive is enabled" do
      before do
        Puppet::Network::HttpPool.stubs(:keep_alive?).returns true
      end

      it "should cache http instances" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).should equal(old)
      end

      it "should have a mechanism for getting a new http instance instead of the cached instance" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321, true).should_not equal(old)
      end

      it "should close existing, open connections when requesting a new connection" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        old.expects(:started?).returns(true)
        old.expects(:finish)
        Puppet::Network::HttpPool.http_instance("me", 54321, true)
      end

      it "should have a mechanism for clearing the http cache" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).should equal(old)
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.clear_http_instances
        Puppet::Network::HttpPool.http_instance("me", 54321).should_not equal(old)
      end

      it "should close open http connections when clearing the cache" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        one = Puppet::Network::HttpPool.http_instance("me", 54321)
        one.expects(:started?).returns(true)
        one.expects(:finish).returns(true)
        Puppet::Network::HttpPool.clear_http_instances
      end

      it "should not close unopened http connections when clearing the cache" do
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
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
        stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :configtimeout => 120
        old = Puppet::Network::HttpPool.http_instance("me", 54321)
        Puppet::Network::HttpPool.http_instance("me", 54321).should_not equal(old)
      end
    end

    after do
      Puppet::Network::HttpPool.clear_http_instances
    end
  end

  describe "when adding certificate information to http instances" do
    before do
      @http = mock 'http'
      [:cert_store=, :verify_mode=, :ca_file=, :cert=, :key=].each { |m| @http.stubs(m) }
      @store = stub 'store'

      @cert = stub 'cert', :content => "real_cert"
      @key = stub 'key', :content => "real_key"
      @host = stub 'host', :certificate => @cert, :key => @key, :ssl_store => @store

      Puppet[:confdir] = "/sometthing/else"
      Puppet.settings.stubs(:value).returns "/some/file"
      Puppet.settings.stubs(:value).with(:hostcert).returns "/host/cert"
      Puppet.settings.stubs(:value).with(:localcacert).returns "/local/ca/cert"

      FileTest.stubs(:exist?).with("/host/cert").returns true
      FileTest.stubs(:exist?).with("/local/ca/cert").returns true

      Puppet::Network::HttpPool.stubs(:ssl_host).returns @host
    end

    after do
      Puppet.settings.clear
    end

    it "should do nothing if no host certificate is on disk" do
      FileTest.expects(:exist?).with("/host/cert").returns false
      @http.expects(:cert=).never
      Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should do nothing if no local certificate is on disk" do
      FileTest.expects(:exist?).with("/local/ca/cert").returns false
      @http.expects(:cert=).never
      Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should add a certificate store from the ssl host" do
      @http.expects(:cert_store=).with(@store)

      Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should add the client certificate" do
      @http.expects(:cert=).with("real_cert")

      Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should add the client key" do
      @http.expects(:key=).with("real_key")

      Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should set the verify mode to OpenSSL::SSL::VERIFY_PEER" do
      @http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

      Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should set the ca file" do
      Puppet.settings.stubs(:value).returns "/some/file"
      FileTest.stubs(:exist?).with(Puppet[:hostcert]).returns true

      Puppet.settings.stubs(:value).with(:localcacert).returns "/ca/cert/file"
      FileTest.stubs(:exist?).with("/ca/cert/file").returns true
      @http.expects(:ca_file=).with("/ca/cert/file")

      Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should set up certificate information when creating http instances" do
      Puppet::Network::HttpPool.expects(:cert_setup).with { |i| i.is_a?(Net::HTTP) }
      Puppet::Network::HttpPool.http_instance("one", "two")
    end
  end
end
