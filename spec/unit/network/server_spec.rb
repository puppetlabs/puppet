#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/server'

describe Puppet::Network::Server do
  let(:port) { 8140 }
  let(:address) { '0.0.0.0' }
  let(:server) { Puppet::Network::Server.new(address, port) }

  before do
    @mock_http_server = mock('http server')
    Puppet.settings.stubs(:use)
    Puppet::Network::HTTP::WEBrick.stubs(:new).returns(@mock_http_server)
  end

  describe "when initializing" do
    before do
      Puppet[:masterport] = ''
    end

    it "should not be listening after initialization" do
      expect(Puppet::Network::Server.new(address, port)).not_to be_listening
    end

    it "should use the :main setting section" do
      Puppet.settings.expects(:use).with { |*args| args.include?(:main) }
      Puppet::Network::Server.new(address, port)
    end

    it "should use the :application setting section" do
      Puppet.settings.expects(:use).with { |*args| args.include?(:application) }

      Puppet::Network::Server.new(address, port)
    end
  end

  describe "when not yet started" do
    before do
      @mock_http_server.stubs(:listen)
    end

    it "should indicate that it is not listening" do
      expect(server).not_to be_listening
    end

    it "should not allow server to be stopped" do
      expect { server.stop }.to raise_error(RuntimeError)
    end

    it "should allow server to be started" do
      expect { server.start }.to_not raise_error
    end
  end

  describe "when server is on" do
    before do
      @mock_http_server.stubs(:listen)
      @mock_http_server.stubs(:unlisten)
      server.start
    end

    it "should indicate that it is listening" do
      expect(server).to be_listening
    end

    it "should not allow server to be started again" do
      expect { server.start }.to raise_error(RuntimeError)
    end

    it "should allow server to be stopped" do
      expect { server.stop }.to_not raise_error
    end
  end

  describe "when server is being started" do
    it "should cause the HTTP server to listen" do
      server = Puppet::Network::Server.new(address, port)
      @mock_http_server.expects(:listen).with(address, port)
      server.start
    end
  end

  describe "when server is being stopped" do
    before do
      @mock_http_server.stubs(:listen)
      server.stubs(:http_server).returns(@mock_http_server)
      server.start
    end

    it "should cause the HTTP server to stop listening" do
      @mock_http_server.expects(:unlisten)
      server.stop
    end
  end
end
