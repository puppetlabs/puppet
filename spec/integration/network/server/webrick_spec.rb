#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/network/server'
require 'puppet/ssl/certificate_authority'
require 'socket'

describe Puppet::Network::Server do
  describe "when using webrick" do
    before :each do
      Puppet[:servertype] = 'webrick'
      Puppet[:server] = '127.0.0.1'
      @params = { :port => 34343, :handlers => [ :node ], :xmlrpc_handlers => [ :status ] }

      # Get a safe temporary file
      @tmpfile = Tempfile.new("webrick_integration_testing")
      @dir = @tmpfile.path + "_dir"

      Puppet.settings[:confdir] = @dir
      Puppet.settings[:vardir] = @dir
      Puppet.settings[:group] = Process.gid

      Puppet::SSL::Host.ca_location = :local

      ca = Puppet::SSL::CertificateAuthority.new
      ca.generate(Puppet[:certname]) unless Puppet::SSL::Certificate.indirection.find(Puppet[:certname])
    end

    after do
      @tmpfile.delete
      Puppet.settings.clear

      system("rm -rf #{@dir}")

      Puppet::SSL::Host.ca_location = :none
      Puppet::Util::Cacher.expire
    end

    describe "before listening" do
      it "should not be reachable at the specified address and port" do
        lambda { TCPSocket.new('127.0.0.1', 34343) }.should raise_error
      end
    end

    describe "when listening" do
      it "should be reachable on the specified address and port" do
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))
        @server.listen
        lambda { TCPSocket.new('127.0.0.1', 34343) }.should_not raise_error
      end

      it "should default to '0.0.0.0' as its bind address" do
        Puppet.settings.clear
        Puppet[:servertype] = 'webrick'
        Puppet[:bindaddress].should == '0.0.0.0'
      end

      it "should use any specified bind address" do
        Puppet[:bindaddress] = "127.0.0.1"
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))
        @server.stubs(:unlisten) # we're breaking listening internally, so we have to keep it from unlistening
        @server.send(:http_server).expects(:listen).with { |args| args[:address] == "127.0.0.1" }
        @server.listen
      end

      it "should not allow multiple servers to listen on the same address and port" do
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))
        @server.listen
        @server2 = Puppet::Network::Server.new(@params.merge(:port => 34343))
        lambda { @server2.listen }.should raise_error
      end

      after :each do
        @server.unlisten if @server && @server.listening?
      end
    end

    describe "after unlistening" do
      it "should not be reachable on the port and address assigned" do
        @server = Puppet::Network::Server.new(@params.merge(:port => 34343))
        @server.listen
        @server.unlisten
        lambda { TCPSocket.new('127.0.0.1', 34343) }.should raise_error(Errno::ECONNREFUSED)
      end
    end
  end
end
