#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http_pool'

describe Puppet::Network::HttpPool do

  describe "when managing http instances" do

    it "should return an http instance created with the passed host and port" do
      http = Puppet::Network::HttpPool.http_instance("me", 54321)
      http.should be_an_instance_of Puppet::Network::HTTP::Connection
      http.address.should == 'me'
      http.port.should    == 54321
    end

    it "should enable ssl on the http instance by default" do
      Puppet::Network::HttpPool.http_instance("me", 54321).should be_use_ssl
    end

    it "can set ssl using an option" do
      Puppet::Network::HttpPool.http_instance("me", 54321, false).should_not be_use_ssl
      Puppet::Network::HttpPool.http_instance("me", 54321, true).should be_use_ssl
    end

    it "should not cache http instances" do
      Puppet::Network::HttpPool.http_instance("me", 54321).
        should_not equal Puppet::Network::HttpPool.http_instance("me", 54321)
    end
  end

end
