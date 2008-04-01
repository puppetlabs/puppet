#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-26.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/network/http_pool'

describe Puppet::Network::HttpPool, " when adding certificate information to http instances" do
    before do
        @http = mock 'http'
        [:cert_store=, :verify_mode=, :ca_file=, :cert=, :key=].each { |m| @http.stubs(m) }
        @store = stub 'store'
        [:add_file,:purpose=].each { |m| @store.stubs(m) }
    end

    it "should have keep-alive disabled" do
        Puppet::Network::HttpPool::HTTP_KEEP_ALIVE.should be_false
    end

    it "should do nothing if no certificate is available" do
        Puppet::Network::HttpPool.expects(:read_cert).returns(false)
        @http.expects(:cert=).never
        Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should add a certificate store" do
        Puppet::Network::HttpPool.stubs(:read_cert).returns(true)
        Puppet::Network::HttpPool.stubs(:key).returns(:mykey)
        OpenSSL::X509::Store.expects(:new).returns(@store)
        @http.expects(:cert_store=).with(@store)

        Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should add the local CA cert to the certificate store" do
        Puppet::Network::HttpPool.stubs(:read_cert).returns(true)
        OpenSSL::X509::Store.expects(:new).returns(@store)
        Puppet.settings.stubs(:value).with(:localcacert).returns("/some/file")
        Puppet.settings.stubs(:value).with(:localcacert).returns("/some/file")
        @store.expects(:add_file).with("/some/file")

        Puppet::Network::HttpPool.stubs(:key).returns(:whatever)

        Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should set the purpose of the cert store to OpenSSL::X509::PURPOSE_SSL_CLIENT" do
        Puppet::Network::HttpPool.stubs(:read_cert).returns(true)
        Puppet::Network::HttpPool.stubs(:key).returns(:mykey)
        OpenSSL::X509::Store.expects(:new).returns(@store)

        @store.expects(:purpose=).with(OpenSSL::X509::PURPOSE_SSL_CLIENT)

        Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should add the client certificate" do
        Puppet::Network::HttpPool.stubs(:read_cert).returns(true)
        Puppet::Network::HttpPool.stubs(:cert).returns(:mycert)
        Puppet::Network::HttpPool.stubs(:key).returns(:mykey)
        OpenSSL::X509::Store.expects(:new).returns(@store)

        @http.expects(:cert=).with(:mycert)

        Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should add the client key" do
        Puppet::Network::HttpPool.stubs(:read_cert).returns(true)
        Puppet::Network::HttpPool.stubs(:key).returns(:mykey)
        OpenSSL::X509::Store.expects(:new).returns(@store)

        @http.expects(:key=).with(:mykey)

        Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should set the verify mode to OpenSSL::SSL::VERIFY_PEER" do
        Puppet::Network::HttpPool.stubs(:read_cert).returns(true)
        Puppet::Network::HttpPool.stubs(:key).returns(:mykey)
        OpenSSL::X509::Store.expects(:new).returns(@store)

        @http.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

        Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should set the ca file" do
        Puppet::Network::HttpPool.stubs(:read_cert).returns(true)
        Puppet.settings.stubs(:value).with(:localcacert).returns("/some/file")
        OpenSSL::X509::Store.expects(:new).returns(@store)

        @http.expects(:ca_file=).with("/some/file")

        Puppet::Network::HttpPool.stubs(:key).returns(:whatever)

        Puppet::Network::HttpPool.cert_setup(@http)
    end

    it "should set up certificate information when creating http instances" do
        Puppet::Network::HttpPool.expects(:cert_setup).with { |i| i.is_a?(Net::HTTP) }
        Puppet::Network::HttpPool.http_instance("one", "two")
    end

    after do
        Puppet::Network::HttpPool.clear_http_instances
    end

    describe "when managing http instances" do
        def stub_settings(settings)
            settings.each do |param, value|
                Puppet.settings.stubs(:value).with(param).returns(value)
            end
        end

        before do
            # All of hte cert stuff is tested elsewhere
            Puppet::Network::HttpPool.stubs(:cert_setup)
        end

        it "should return an http instance created with the passed host and port" do
            http = stub 'http', :use_ssl= => nil, :read_timeout= => nil, :open_timeout= => nil, :enable_post_connection_check= => nil, :started? => false
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

        it "should default to http_enable_post_connection_check being enabled" do
            Puppet.settings[:http_enable_post_connection_check].should be_true
        end

        # JJM: I'm not sure if this is correct, as this really follows the
        # configuration option.
        it "should set enable_post_connection_check true " do
            Puppet::Network::HttpPool.http_instance("me", 54321).instance_variable_get("@enable_post_connection_check").should be_true
        end

        it "should create the http instance with the proxy host and port set if the http_proxy is not set to 'none'" do
            stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :http_enable_post_connection_check => true
            Puppet::Network::HttpPool.http_instance("me", 54321).open_timeout.should == 120
        end

        describe "when http keep-alive is enabled" do
            before do
                Puppet::Network::HttpPool.stubs(:keep_alive?).returns true
            end

            it "should cache http instances" do
                stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :http_enable_post_connection_check => true
                old = Puppet::Network::HttpPool.http_instance("me", 54321)
                Puppet::Network::HttpPool.http_instance("me", 54321).should equal(old)
            end

            it "should have a mechanism for getting a new http instance instead of the cached instance" do
                stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :http_enable_post_connection_check => true
                old = Puppet::Network::HttpPool.http_instance("me", 54321)
                Puppet::Network::HttpPool.http_instance("me", 54321, true).should_not equal(old)
            end

            it "should close existing, open connections when requesting a new connection" do
                stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :http_enable_post_connection_check => true
                old = Puppet::Network::HttpPool.http_instance("me", 54321)
                old.expects(:started?).returns(true)
                old.expects(:finish)
                Puppet::Network::HttpPool.http_instance("me", 54321, true)
            end

            it "should have a mechanism for clearing the http cache" do
                stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :http_enable_post_connection_check => true
                old = Puppet::Network::HttpPool.http_instance("me", 54321)
                Puppet::Network::HttpPool.http_instance("me", 54321).should equal(old)
                old = Puppet::Network::HttpPool.http_instance("me", 54321)
                Puppet::Network::HttpPool.clear_http_instances
                Puppet::Network::HttpPool.http_instance("me", 54321).should_not equal(old)
            end

            it "should close open http connections when clearing the cache" do
                stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :http_enable_post_connection_check => true
                one = Puppet::Network::HttpPool.http_instance("me", 54321)
                one.expects(:started?).returns(true)
                one.expects(:finish).returns(true)
                Puppet::Network::HttpPool.clear_http_instances
            end

            it "should not close unopened http connections when clearing the cache" do
                stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :http_enable_post_connection_check => true
                one = Puppet::Network::HttpPool.http_instance("me", 54321)
                one.expects(:started?).returns(false)
                one.expects(:finish).never
                Puppet::Network::HttpPool.clear_http_instances
            end
        end

        describe "when http keep-alive is disabled" do
            before do
                Puppet::Network::HttpPool.stubs(:keep_alive?).returns false
            end

            it "should not cache http instances" do
                stub_settings :http_proxy_host => "myhost", :http_proxy_port => 432, :http_enable_post_connection_check => true
                old = Puppet::Network::HttpPool.http_instance("me", 54321)
                Puppet::Network::HttpPool.http_instance("me", 54321).should_not equal(old)
            end
        end

        # We mostly have to do this for testing, since in real life people
        # won't change certs within a single process.
        it "should remove its loaded certificate when clearing the cache" do
            Puppet::Network::HttpPool.instance_variable_set("@cert", :yay)
            Puppet::Network::HttpPool.clear_http_instances
            # Can't use the accessor, because it will read the cert in
            Puppet::Network::HttpPool.instance_variable_get("@cert").should be_nil
        end

        # We mostly have to do this for testing, since in real life people
        # won't change certs within a single process.
        it "should remove its loaded key when clearing the cache" do
            Puppet::Network::HttpPool.instance_variable_set("@key", :yay)
            Puppet::Network::HttpPool.clear_http_instances
            # Can't use the accessor, because it will read the cert in
            Puppet::Network::HttpPool.instance_variable_get("@key").should be_nil
        end

        after do
            Puppet::Network::HttpPool.clear_http_instances
        end
    end
end
