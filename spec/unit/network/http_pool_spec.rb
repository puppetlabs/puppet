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


    describe 'peer verification' do
      def setup_standard_ssl_configuration
        ca_cert_file = File.expand_path('/path/to/ssl/certs/ca_cert.pem')
        Puppet::FileSystem::File.stubs(:exist?).with(ca_cert_file).returns(true)

        ssl_configuration = stub('ssl_configuration', :ca_auth_file => ca_cert_file)
        Puppet::Network::HTTP::Connection.any_instance.stubs(:ssl_configuration).returns(ssl_configuration)
      end

      def setup_standard_hostcert
        host_cert_file = File.expand_path('/path/to/ssl/certs/host_cert.pem')
        Puppet::FileSystem::File.stubs(:exist?).with(host_cert_file).returns(true)

        Puppet[:hostcert] = host_cert_file
      end

      def setup_standard_ssl_host
        cert = stub('cert', :content => 'real_cert')
        key  = stub('key',  :content => 'real_key')
        host = stub('host', :certificate => cert, :key => key, :ssl_store => stub('store'))

        Puppet::Network::HTTP::Connection.any_instance.stubs(:ssl_host).returns(host)
      end

      before do
        setup_standard_ssl_configuration
        setup_standard_hostcert
        setup_standard_ssl_host
      end

      it 'can enable peer verification' do
        Puppet::Network::HttpPool.http_instance("me", 54321, true, true).send(:connection).verify_mode.should == OpenSSL::SSL::VERIFY_PEER
      end

      it 'can disable peer verification' do
        Puppet::Network::HttpPool.http_instance("me", 54321, true, false).send(:connection).verify_mode.should == OpenSSL::SSL::VERIFY_NONE
      end
    end

    it "should not cache http instances" do
      Puppet::Network::HttpPool.http_instance("me", 54321).
        should_not equal Puppet::Network::HttpPool.http_instance("me", 54321)
    end
  end

end
