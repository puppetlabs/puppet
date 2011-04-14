#!/usr/bin/env rspec
require 'puppet/network/client'

require 'spec_helper'

describe Puppet::Network::XMLRPCClient do
  describe "when performing the rpc call" do
    before do
      Puppet::SSL::Host.any_instance.stubs(:certificate_matches_key?).returns true
      @client = Puppet::Network::Client.report.xmlrpc_client.new
      @client.stubs(:call).returns "foo"
    end

    it "should call the specified namespace and method, with the specified arguments" do
      @client.expects(:call).with("puppetreports.report", "eh").returns "foo"
      @client.report("eh")
    end

    it "should return the results from the call" do
      @client.expects(:call).returns "foo"
      @client.report("eh").should == "foo"
    end

    it "should always close the http connection if it is still open after the call" do
      http = mock 'http'
      @client.stubs(:http).returns http

      http.expects(:started?).returns true
      http.expects(:finish)

      @client.report("eh").should == "foo"
    end

    it "should always close the http connection if it is still open after a call that raises an exception" do
      http = mock 'http'
      @client.stubs(:http).returns http

      @client.expects(:call).raises RuntimeError

      http.expects(:started?).returns true
      http.expects(:finish)

      lambda { @client.report("eh") }.should raise_error
    end

    describe "when returning the http instance" do
      it "should use the http pool to create the instance" do
        @client.instance_variable_set("@http", nil)
        @client.expects(:host).returns "myhost"
        @client.expects(:port).returns "myport"
        Puppet::Network::HttpPool.expects(:http_instance).with("myhost", "myport", true).returns "http"

        @client.http.should == "http"
      end

      it "should reuse existing instances" do
        @client.http.should equal(@client.http)
      end
    end

    describe "when recycling the connection" do
      it "should close the existing instance if it's open" do
        http = mock 'http'
        @client.stubs(:http).returns http

        http.expects(:started?).returns true
        http.expects(:finish)

        @client.recycle_connection
      end

      it "should force creation of a new instance" do
        Puppet::Network::HttpPool.expects(:http_instance).returns "second_http"

        @client.recycle_connection

        @client.http.should == "second_http"
      end
    end

    describe "and an exception is raised" do
      it "should raise XMLRPCClientError if XMLRPC::FaultException is raised" do
        error = XMLRPC::FaultException.new("foo", "bar")

        @client.expects(:call).raises(error)

        lambda { @client.report("eh") }.should raise_error(Puppet::Network::XMLRPCClientError)
      end

      it "should raise XMLRPCClientError if Errno::ECONNREFUSED is raised" do
        @client.expects(:call).raises(Errno::ECONNREFUSED)

        lambda { @client.report("eh") }.should raise_error(Puppet::Network::XMLRPCClientError)
      end

      it "should log and raise XMLRPCClientError if Timeout::Error is raised" do
        Puppet.expects(:err)
        @client.expects(:call).raises(Timeout::Error)

        lambda { @client.report("eh") }.should raise_error(Puppet::Network::XMLRPCClientError)
      end

      it "should log and raise XMLRPCClientError if SocketError is raised" do
        Puppet.expects(:err)
        @client.expects(:call).raises(SocketError)

        lambda { @client.report("eh") }.should raise_error(Puppet::Network::XMLRPCClientError)
      end

      it "should log, recycle the connection, and retry if Errno::EPIPE is raised" do
        @client.expects(:call).times(2).raises(Errno::EPIPE).then.returns "eh"

        Puppet.expects(:info)
        @client.expects(:recycle_connection)

        @client.report("eh")
      end

      it "should log, recycle the connection, and retry if EOFError is raised" do
        @client.expects(:call).times(2).raises(EOFError).then.returns "eh"

        Puppet.expects(:info)
        @client.expects(:recycle_connection)

        @client.report("eh")
      end

      it "should log and retry if an exception containing 'Wrong size' is raised" do
        error = RuntimeError.new("Wrong size. Was 15, should be 30")
        @client.expects(:call).times(2).raises(error).then.returns "eh"

        Puppet.expects(:warning)

        @client.report("eh")
      end

      it "should raise XMLRPCClientError if OpenSSL::SSL::SSLError is raised" do
        @client.expects(:call).raises(OpenSSL::SSL::SSLError)

        lambda { @client.report("eh") }.should raise_error(Puppet::Network::XMLRPCClientError)
      end

      it "should log and raise XMLRPCClientError if OpenSSL::SSL::SSLError is raised with certificate issues" do
        error = OpenSSL::SSL::SSLError.new("hostname was not match")
        @client.expects(:call).raises(error)

        Puppet.expects(:warning)

        lambda { @client.report("eh") }.should raise_error(Puppet::Network::XMLRPCClientError)
      end

      it "should log, recycle the connection, and retry if OpenSSL::SSL::SSLError is raised containing 'bad write retry'" do
        error = OpenSSL::SSL::SSLError.new("bad write retry")
        @client.expects(:call).times(2).raises(error).then.returns "eh"

        @client.expects(:recycle_connection)

        Puppet.expects(:warning)

        @client.report("eh")
      end

      it "should log and raise XMLRPCClientError if any other exception is raised" do
        @client.expects(:call).raises(RuntimeError)

        Puppet.expects(:err)

        lambda { @client.report("eh") }.should raise_error(Puppet::Network::XMLRPCClientError)
      end
    end
  end
end
