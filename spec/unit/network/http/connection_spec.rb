#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http/connection'
require 'puppet/network/authentication'

describe Puppet::Network::HTTP::Connection do

  let (:host) { "me" }
  let (:port) { 54321 }
  subject { Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator) }
  let (:httpok) { Net::HTTPOK.new('1.1', 200, '') }

  context "when providing HTTP connections" do
    after do
      Puppet::Network::HTTP::Connection.instance_variable_set("@ssl_host", nil)
    end

    context "when initializing http instances" do
      before :each do
        # All of the cert stuff is tested elsewhere
        Puppet::Network::HTTP::Connection.stubs(:cert_setup)
      end

      it "should return an http instance created with the passed host and port" do
        http = subject.send(:connection)
        http.should be_an_instance_of Net::HTTP
        http.address.should == host
        http.port.should    == port
      end

      it "should enable ssl on the http instance by default" do
        http = subject.send(:connection)
        http.should be_use_ssl
      end

      it "can set ssl using an option" do
        Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => false, :verify => Puppet::SSL::Validator.no_validator).send(:connection).should_not be_use_ssl
        Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true, :verify => Puppet::SSL::Validator.no_validator).send(:connection).should be_use_ssl
      end

      context "proxy and timeout settings should propagate" do
        subject { Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator).send(:connection) }
        before :each do
          Puppet[:http_proxy_host] = "myhost"
          Puppet[:http_proxy_port] = 432
          Puppet[:configtimeout]   = 120
        end

        its(:open_timeout)  { should == Puppet[:configtimeout] }
        its(:read_timeout)  { should == Puppet[:configtimeout] }
        its(:proxy_address) { should == Puppet[:http_proxy_host] }
        its(:proxy_port)    { should == Puppet[:http_proxy_port] }
      end

      it "should not set a proxy if the value is 'none'" do
        Puppet[:http_proxy_host] = 'none'
        subject.send(:connection).proxy_address.should be_nil
      end

      it "should raise Puppet::Error when invalid options are specified" do
        expect { Puppet::Network::HTTP::Connection.new(host, port, :invalid_option => nil) }.to raise_error(Puppet::Error, 'Unrecognized option(s): :invalid_option')
      end
    end
  end

  context "when methods that accept a block are called with a block" do
    let (:host) { "my_server" }
    let (:port) { 8140 }
    let (:subject) { Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => false, :verify => Puppet::SSL::Validator.no_validator) }

    before :each do
      httpok.stubs(:body).returns ""

      # This stubbing relies a bit more on knowledge of the internals of Net::HTTP
      # than I would prefer, but it works on ruby 1.8.7 and 1.9.3, and it seems
      # valuable enough to have tests for blocks that this is probably warranted.
      socket = stub_everything("socket")
      TCPSocket.stubs(:open).returns(socket)

      Net::HTTP::Post.any_instance.stubs(:exec).returns("")
      Net::HTTP::Head.any_instance.stubs(:exec).returns("")
      Net::HTTP::Get.any_instance.stubs(:exec).returns("")
      Net::HTTPResponse.stubs(:read_new).returns(httpok)
    end

    [:request_get, :request_head, :request_post].each do |method|
      context "##{method}" do
        it "should yield to the block" do
          block_executed = false
          subject.send(method, "/foo", {}) do |response|
            block_executed = true
          end
          block_executed.should == true
        end
      end
    end
  end

  context "when validating HTTPS requests" do
    include PuppetSpec::Files

    let (:host) { "my_server" }
    let (:port) { 8140 }

    it "should provide a useful error message when one is available and certificate validation fails", :unless => Puppet.features.microsoft_windows? do
      connection = Puppet::Network::HTTP::Connection.new(
        host, port,
        :verify => ConstantErrorValidator.new(:fails_with => 'certificate verify failed',
                                              :error_string => 'shady looking signature'))

      expect do
        connection.get('request')
      end.to raise_error(Puppet::Error, "certificate verify failed: [shady looking signature]")
    end

    it "should provide a helpful error message when hostname was not match with server certificate", :unless => Puppet.features.microsoft_windows? do
      Puppet[:confdir] = tmpdir('conf')

      connection = Puppet::Network::HTTP::Connection.new(
        host, port,
        :verify => ConstantErrorValidator.new(
          :fails_with => 'hostname was not match with server certificate',
          :peer_certs => [Puppet::SSL::CertificateAuthority.new.generate(
            'not_my_server', :dns_alt_names => 'foo,bar,baz')]))

      expect do
        connection.get('request')
      end.to raise_error(Puppet::Error) do |error|
        error.message =~ /Server hostname 'my_server' did not match server certificate; expected one of (.+)/
        $1.split(', ').should =~ %w[DNS:foo DNS:bar DNS:baz DNS:not_my_server not_my_server]
      end
    end

    it "should pass along the error message otherwise" do
      connection = Puppet::Network::HTTP::Connection.new(
        host, port,
        :verify => ConstantErrorValidator.new(:fails_with => 'some other message'))

      expect do
        connection.get('request')
      end.to raise_error(/some other message/)
    end

    it "should check all peer certificates for upcoming expiration", :unless => Puppet.features.microsoft_windows? do
      Puppet[:confdir] = tmpdir('conf')
      cert = Puppet::SSL::CertificateAuthority.new.generate(
        'server', :dns_alt_names => 'foo,bar,baz')

      connection = Puppet::Network::HTTP::Connection.new(
        host, port,
        :verify => NoProblemsValidator.new(cert))

      Net::HTTP.any_instance.stubs(:request).returns(httpok)

      connection.expects(:warn_if_near_expiration).with(cert)

      connection.get('request')
    end

    class ConstantErrorValidator
      def initialize(args)
        @fails_with = args[:fails_with]
        @error_string = args[:error_string] || ""
        @peer_certs = args[:peer_certs] || []
      end

      def setup_connection(connection)
        connection.stubs(:request).with do
          true
        end.raises(OpenSSL::SSL::SSLError.new(@fails_with))
      end

      def peer_certs
        @peer_certs
      end

      def verify_errors
        [@error_string]
      end
    end

    class NoProblemsValidator
      def initialize(cert)
        @cert = cert
      end

      def setup_connection(connection)
      end

      def peer_certs
        [@cert]
      end

      def verify_errors
        []
      end
    end
  end

  context "when response is a redirect" do
    let (:other_host) { "redirected" }
    let (:other_port) { 9292 }
    let (:other_path) { "other-path" }
    let (:subject) { Puppet::Network::HTTP::Connection.new("my_server", 8140, :use_ssl => false, :verify => Puppet::SSL::Validator.no_validator) }
    let (:httpredirection) { Net::HTTPFound.new('1.1', 302, 'Moved Temporarily') }

    before :each do
      httpredirection['location'] = "http://#{other_host}:#{other_port}/#{other_path}"
      httpredirection.stubs(:read_body).returns("This resource has moved")

      socket = stub_everything("socket")
      TCPSocket.stubs(:open).returns(socket)

      Net::HTTP::Get.any_instance.stubs(:exec).returns("")
      Net::HTTP::Post.any_instance.stubs(:exec).returns("")
    end

    it "should redirect to the final resource location" do
      httpok.stubs(:read_body).returns(:body)
      Net::HTTPResponse.stubs(:read_new).returns(httpredirection).then.returns(httpok)

      subject.get("/foo").body.should == :body
      subject.port.should == other_port
      subject.address.should == other_host
    end

    it "should raise an error after too many redirections" do
      Net::HTTPResponse.stubs(:read_new).returns(httpredirection)

      expect {
        subject.get("/foo")
      }.to raise_error(Puppet::Network::HTTP::RedirectionLimitExceededException)
    end
  end

  context "when response is a 503 or an exception is raised" do
    let (:subject) { Puppet::Network::HTTP::Connection.new("my_server", 8140, :use_ssl => false, :verify => Puppet::SSL::Validator.no_validator) }
    let (:httpretry) { Net::HTTPServiceUnavailable.new('1.1', 503, 'Service Temporarily Unavailable') }
    let (:httpretry_body) { 'This page is temporarily unavailable' }
    before :each do
      httpretry.stubs(:read_body).returns(:httpretry_body)

      socket = stub_everything("socket")
      TCPSocket.stubs(:open).returns(socket)

      Net::HTTP::Get.any_instance.stubs(:exec).returns("")
      Net::HTTP::Put.any_instance.stubs(:exec).returns("")
    end

    it "should retry idempotent requests" do
      httpok.stubs(:read_body).returns(:body)
      Net::HTTPResponse.stubs(:read_new).returns(httpretry).then.returns(httpok)

      subject.expects(:sleep).once
      subject.get("/foo").body.should == :body
    end

    it "should not retry non-idempotent requests" do
      httpok.stubs(:read_body).returns(:body)

      subject.expects(:sleep).never
      subject.expects(:execute_request).once.returns(httpretry)
      subject.put("/foo", "").body.should == :httpretry_body
    end

    it "should return retry response after too many retries" do
      Net::HTTPResponse.stubs(:read_new).returns(httpretry)

      subject.expects(:sleep).twice
      subject.get("/foo").body.should == :httpretry_body
    end

    it "should raise retry exception after too many exceptions" do
      Net::HTTPResponse.stubs(:read_new).raises(Net::HTTPBadResponse)

      subject.expects(:sleep).twice
      expect {
        subject.get("/foo")
      }.to raise_error(Puppet::Network::HTTP::RetryLimitExceededException)
    end
  end

  it "allows setting basic auth on get requests" do
    expect_request_with_basic_auth

    subject.get('/path', nil, :basic_auth => { :user => 'user', :password => 'password' })
  end

  it "allows setting basic auth on post requests" do
    expect_request_with_basic_auth

    subject.post('/path', 'data', nil, :basic_auth => { :user => 'user', :password => 'password' })
  end

  it "allows setting basic auth on head requests" do
    expect_request_with_basic_auth

    subject.head('/path', nil, :basic_auth => { :user => 'user', :password => 'password' })
  end

  it "allows setting basic auth on delete requests" do
    expect_request_with_basic_auth

    subject.delete('/path', nil, :basic_auth => { :user => 'user', :password => 'password' })
  end

  it "allows setting basic auth on put requests" do
    expect_request_with_basic_auth

    subject.put('/path', 'data', nil, :basic_auth => { :user => 'user', :password => 'password' })
  end

  def expect_request_with_basic_auth
    Net::HTTP.any_instance.expects(:request).with do |request|
      expect(request['authorization']).to match(/^Basic/)
    end.returns(httpok)
  end
end
