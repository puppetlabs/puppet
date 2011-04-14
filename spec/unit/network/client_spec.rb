#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2008-3-24.
#  Copyright (c) 2008. All rights reserved.

require 'spec_helper'

require 'puppet/network/client'

describe Puppet::Network::Client do
  before do
    Puppet.settings.stubs(:use).returns(true)
    Puppet::Network::HttpPool.stubs(:cert_setup)
  end

  describe "when keep-alive is enabled" do
    before do
      Puppet::Network::HttpPool.stubs(:keep_alive?).returns true
    end
    it "should start the http client up on creation" do
      http = mock 'http'
      http.stub_everything
      http.expects(:start)
      Net::HTTP.stubs(:new).returns http

      # Pick a random subclass...
      Puppet::Network::Client.runner.new :Server => Puppet[:server]
    end
  end

  describe "when keep-alive is disabled" do
    before do
      Puppet::Network::HttpPool.stubs(:keep_alive?).returns false
    end
    it "should not start the http client up on creation" do
      http = mock 'http'
      http.stub_everything
      http.expects(:start).never
      Net::HTTP.stubs(:new).returns http

      # Pick a random subclass...
      Puppet::Network::Client.runner.new :Server => Puppet[:server]
    end
  end
end
