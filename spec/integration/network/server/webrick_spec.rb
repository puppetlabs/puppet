#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/server'
require 'puppet/ssl/certificate_authority'
require 'socket'

describe Puppet::Network::Server, :unless => Puppet.features.microsoft_windows? do
  describe "when using webrick" do
  include PuppetSpec::Files

    # This reduces the odds of conflicting port numbers between concurrent runs
    # of the suite on the same machine dramatically.
    let(:port) { 20000 + ($$ % 40000) }
    let(:address) { '127.0.0.1' }

    before :each do
      Puppet[:server] = '127.0.0.1'

      # Get a safe temporary file
      dir = tmpdir("webrick_integration_testing")

      Puppet.settings[:confdir] = dir
      Puppet.settings[:vardir] = dir
      Puppet.settings[:logdir] = dir
      Puppet.settings[:group] = Process.gid

      Puppet::SSL::Host.ca_location = :local

      ca = Puppet::SSL::CertificateAuthority.new
      ca.generate(Puppet[:certname]) unless Puppet::SSL::Certificate.indirection.find(Puppet[:certname])

      @server = Puppet::Network::Server.new(address, port)
    end

    after do
      Puppet::SSL::Host.ca_location = :none
    end

    describe "before listening" do
      it "should not be reachable at the specified address and port" do
        expect { TCPSocket.new('127.0.0.1', port) }.to raise_error
      end
    end

    describe "when listening" do
      it "should be reachable on the specified address and port" do
        @server.start
        expect { TCPSocket.new('127.0.0.1', port) }.to_not raise_error
      end

      it "should use any specified bind address" do
        @server.stubs(:stop) # we're breaking listening internally, so we have to keep it from unlistening
        Puppet::Network::HTTP::WEBrick.any_instance.expects(:listen).with(address, port)
        @server.start
      end

      it "should not allow multiple servers to listen on the same address and port" do
        @server.start
        server2 = Puppet::Network::Server.new(address, port)
        expect { server2.start }.to raise_error
      end

      after :each do
        @server.stop if @server && @server.listening?
      end
    end

    describe "after unlistening" do
      it "should not be reachable on the port and address assigned" do
        @server.start
        @server.stop
        expect { TCPSocket.new('127.0.0.1', port) }.to raise_error(Errno::ECONNREFUSED)
      end
    end
  end
end
