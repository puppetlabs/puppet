#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-26.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/xmlrpc/client'

describe Puppet::Network::XMLRPCClient, " when managing http instances" do
    it "should return an http instance created with the passed host and port" do
        http = stub 'http', :use_ssl= => nil, :read_timeout= => nil, :open_timeout= => nil
        Net::HTTP.expects(:new).with("me", 54321, nil, nil).returns(http)
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).should equal(http)
    end

    it "should enable ssl on the http instance" do
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).instance_variable_get("@use_ssl").should be_true
    end

    it "should set the read timeout" do
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).read_timeout.should == 120
    end

    it "should set the open timeout" do
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).open_timeout.should == 120
    end

    it "should create the http instance with the proxy host and port set if the http_proxy is not set to 'none'" do
        Puppet.settings.stubs(:value).with(:http_keepalive).returns(true)
        Puppet.settings.stubs(:value).with(:http_proxy_host).returns("myhost")
        Puppet.settings.stubs(:value).with(:http_proxy_port).returns(432)
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).open_timeout.should == 120
    end

    it "should default to keep-alive being enabled" do
        Puppet.settings[:http_keepalive].should be_true
    end

    it "should cache http instances if keepalive is enabled" do
        Puppet.settings.stubs(:value).with(:http_keepalive).returns(true)
        Puppet.settings.stubs(:value).with(:http_proxy_host).returns("myhost")
        Puppet.settings.stubs(:value).with(:http_proxy_port).returns(432)
        old = Puppet::Network::XMLRPCClient.http_instance("me", 54321)
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).should equal(old)
    end

    it "should not cache http instances if keepalive is not enabled" do
        Puppet.settings.stubs(:value).with(:http_keepalive).returns(false)
        Puppet.settings.stubs(:value).with(:http_proxy_host).returns("myhost")
        Puppet.settings.stubs(:value).with(:http_proxy_port).returns(432)
        old = Puppet::Network::XMLRPCClient.http_instance("me", 54321)
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).should_not equal(old)
    end

    it "should have a mechanism for clearing the http cache" do
        Puppet.settings.stubs(:value).with(:http_keepalive).returns(true)
        Puppet.settings.stubs(:value).with(:http_proxy_host).returns("myhost")
        Puppet.settings.stubs(:value).with(:http_proxy_port).returns(432)
        old = Puppet::Network::XMLRPCClient.http_instance("me", 54321)
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).should equal(old)
        old = Puppet::Network::XMLRPCClient.http_instance("me", 54321)
        Puppet::Network::XMLRPCClient.clear_http_instances
        Puppet::Network::XMLRPCClient.http_instance("me", 54321).should_not equal(old)
    end

    after do
        Puppet::Network::XMLRPCClient.clear_http_instances
    end
end
