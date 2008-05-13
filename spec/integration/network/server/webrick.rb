#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/server'
require 'puppet/ssl/certificate_authority'
require 'socket'

describe Puppet::Network::Server do
    describe "when using webrick" do
        before :each do
            Puppet[:servertype] = 'webrick'
            @params = { :address => "127.0.0.1", :port => 34343, :handlers => [ :node ], :xmlrpc_handlers => [ :status ] }

            # Get a safe temporary file
            @tmpfile = Tempfile.new("webrick_integration_testing")
            @dir = @tmpfile.path + "_dir"

            Puppet.settings[:confdir] = @dir
            Puppet.settings[:vardir] = @dir

            Puppet::SSL::Host.ca_location = :local

            ca = Puppet::SSL::CertificateAuthority.new
            ca.generate(Puppet[:certname]) unless Puppet::SSL::Certificate.find(Puppet[:certname])
        end

        after do
            @tmpfile.delete
            Puppet.settings.clear

            system("rm -rf %s" % @dir)

            Puppet::Util::Cacher.invalidate
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

            it "should not allow multiple servers to listen on the same address and port" do
                @server = Puppet::Network::Server.new(@params.merge(:port => 34343))      
                @server.listen
                @server2 = Puppet::Network::Server.new(@params.merge(:port => 34343))
                lambda { @server2.listen }.should raise_error
            end

            after :each do
                @server.unlisten if @server.listening?
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
