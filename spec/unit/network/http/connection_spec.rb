#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http/connection'
require 'puppet/network/authentication'

describe Puppet::Network::HTTP::Connection do

  let (:host) { "me" }
  let (:port) { 54321 }
  subject { Puppet::Network::HTTP::Connection.new(host, port) }

  context "when providing HTTP connections" do
    after do
      Puppet::Network::HTTP::Connection.instance_variable_set("@ssl_host", nil)
    end

    it "should use the global SSL::Host instance to get its certificate information" do
      host = mock 'host'
      Puppet::SSL::Host.expects(:localhost).with.returns host
      subject.send(:ssl_host).should equal(host)
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
        Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => false).send(:connection).should_not be_use_ssl
        Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true).send(:connection).should be_use_ssl
      end

      describe "peer verification" do
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

        it "can enable peer verification" do
          Puppet::Network::HTTP::Connection.new(host, port, :verify_peer => true).send(:connection).verify_mode.should == OpenSSL::SSL::VERIFY_PEER
        end

        it "can disable peer verification" do
          Puppet::Network::HTTP::Connection.new(host, port, :verify_peer => false).send(:connection).verify_mode.should == OpenSSL::SSL::VERIFY_NONE
        end
      end

      context "proxy and timeout settings should propagate" do
        subject { Puppet::Network::HTTP::Connection.new(host, port).send(:connection) }
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

    describe "when doing SSL setup for http instances" do
      let :store do stub('store') end

      let :ca_auth_file do
        '/path/to/ssl/certs/ssl_server_ca_auth.pem'
      end

      let :ssl_configuration do
        stub('ssl_configuration', :ca_auth_file => ca_auth_file)
      end

      before :each do
        Puppet[:hostcert]    = '/host/cert'
        Puppet::Network::HTTP::Connection.any_instance.stubs(:ssl_configuration).returns(ssl_configuration)

        cert  = stub 'cert', :content => 'real_cert'
        key   = stub 'key',  :content => 'real_key'
        host  = stub 'host', :certificate => cert, :key => key, :ssl_store => store
        Puppet::Network::HTTP::Connection.any_instance.stubs(:ssl_host).returns(host)
      end

      shared_examples "HTTPS setup without all certificates" do
        subject { Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true).send(:connection) }

        it                { should be_use_ssl }
        its(:cert)        { should be_nil }
        its(:ca_file)     { should be_nil }
        its(:key)         { should be_nil }
        its(:verify_mode) { should == OpenSSL::SSL::VERIFY_NONE }
      end

      context "with neither a host cert or a local CA cert" do
        before :each do
          Puppet::FileSystem::File.stubs(:exist?).with(Puppet[:hostcert]).returns(false)
          Puppet::FileSystem::File.stubs(:exist?).with(ca_auth_file).returns(false)
        end

        include_examples "HTTPS setup without all certificates"
      end

      context "with there is no host certificate" do
        before :each do
          Puppet::FileSystem::File.stubs(:exist?).with(Puppet[:hostcert]).returns(false)
          Puppet::FileSystem::File.stubs(:exist?).with(ca_auth_file).returns(true)
        end

        include_examples "HTTPS setup without all certificates"
      end

      context "with there is no local CA certificate" do
        before :each do
          Puppet::FileSystem::File.stubs(:exist?).with(Puppet[:hostcert]).returns(true)
          Puppet::FileSystem::File.stubs(:exist?).with(ca_auth_file).returns(false)
        end

        include_examples "HTTPS setup without all certificates"
      end

      context "with both the host and CA cert" do
        subject { Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true).send(:connection) }

        before :each do
          Puppet::FileSystem::File.expects(:exist?).with(Puppet[:hostcert]).returns(true)
          Puppet::FileSystem::File.expects(:exist?).with(ca_auth_file).returns(true)
        end

        it                { should be_use_ssl }
        its(:cert_store)  { should equal store }
        its(:cert)        { should == "real_cert" }
        its(:key)         { should == "real_key" }
        its(:verify_mode) { should == OpenSSL::SSL::VERIFY_PEER }
        its(:ca_file)     { should == ca_auth_file }
      end

      it "should set up certificate information when creating http instances" do
        subject.expects(:cert_setup)
        subject.send(:connection)
      end
    end
  end

  context "when methods that accept a block are called with a block" do
    let (:host) { "my_server" }
    let (:port) { 8140 }
    let (:subject) { Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => false) }
    let (:httpok) { Net::HTTPOK.new('1.1', 200, '') }

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
    let (:httpok) { Net::HTTPOK.new('1.1', 200, '') }
    let (:subject) { Puppet::Network::HTTP::Connection.new(host, port) }

    def a_connection_that_verifies(args)
      connection = Net::HTTP.new(host, port)
      connection.stubs(:warn_if_near_expiration)
      connection.stubs(:get).with do
        connection.verify_callback.call(args[:has_passed_pre_checks], args[:in_context])
        true
      end.raises(OpenSSL::SSL::SSLError.new(args[:fails_with]))
      connection
    end

    def a_store_context(args)
      Puppet[:confdir] = tmpdir('conf')
      ssl_context = mock('OpenSSL::X509::StoreContext')
      if args[:verify_raises]
        ssl_context.stubs(:current_cert).raises("oh noes")
      else
        cert = Puppet::SSL::CertificateAuthority.new.generate(args[:for_server], :dns_alt_names => args[:for_aliases]).content
        ssl_context.stubs(:current_cert).returns(cert)
      end
      ssl_context.stubs(:chain).returns([])
      ssl_context.stubs(:error_string).returns(args[:with_error_string])
      ssl_context
    end

    it "should provide a useful error message when one is available and certificate validation fails", :unless => Puppet.features.microsoft_windows? do
      subject.stubs(:create_connection).
          returns(a_connection_that_verifies(:has_passed_pre_checks => false,
                                             :in_context => a_store_context(:for_server => 'not_my_server',
                                                                            :with_error_string => 'shady looking signature'),
                                             :fails_with => 'certificate verify failed'))
      expect do
        subject.request(:get, stub('request'))
      end.to raise_error(Puppet::Error, "certificate verify failed: [shady looking signature for /CN=not_my_server]")
    end

    it "should provide a useful error message when verify_callback raises", :unless => Puppet.features.microsoft_windows? do
      subject.stubs(:create_connection).
          returns(a_connection_that_verifies(:has_passed_pre_checks => false,
                                             :in_context => a_store_context(:verify_raises => true),
                                             :fails_with => 'certificate verify failed'))
      expect do
        subject.request(:get, stub('request'))
      end.to raise_error(Puppet::Error, "certificate verify failed: [oh noes]")
    end

    it "should provide a helpful error message when hostname was not match with server certificate", :unless => Puppet.features.microsoft_windows? do
      subject.stubs(:create_connection).
          returns(a_connection_that_verifies(:has_passed_pre_checks => true,
                                             :in_context => a_store_context(:for_server => 'not_my_server',
                                                                            :for_aliases => 'foo,bar,baz'),
                                             :fails_with => 'hostname was not match with server certificate'))

      expect { subject.request(:get, stub('request')) }.
          to raise_error(Puppet::Error) do |error|
        error.message =~ /Server hostname 'my_server' did not match server certificate; expected one of (.+)/
        $1.split(', ').should =~ %w[DNS:foo DNS:bar DNS:baz DNS:not_my_server not_my_server]
      end
    end

    it "should pass along the error message otherwise" do
      connection = Net::HTTP.new('my_server', 8140)
      subject.stubs(:create_connection).returns(connection)

      connection.stubs(:get).raises(OpenSSL::SSL::SSLError.new('some other message'))

      expect do
        subject.request(:get, stub('request'))
      end.to raise_error(/some other message/)
    end

    it "should check all peer certificates for upcoming expiration", :unless => Puppet.features.microsoft_windows? do
      connection = Net::HTTP.new('my_server', 8140)
      subject.stubs(:create_connection).returns(connection)

      cert = stubs 'cert'
      Puppet::SSL::Certificate.expects(:from_instance).twice.returns(cert)

      connection.stubs(:get).with do
        context = a_store_context(:for_server => 'a_server', :with_error_string => false)
        connection.verify_callback.call(true, context)
        connection.verify_callback.call(true, context)
        true
      end.returns(httpok)

      subject.expects(:warn_if_near_expiration).with(cert, cert)

      subject.request(:get, stubs('request'))
    end
  end

  context "when response is a redirect" do
    let (:other_host) { "redirected" }
    let (:other_port) { 9292 }
    let (:other_path) { "other-path" }
    let (:subject) { Puppet::Network::HTTP::Connection.new("my_server", 8140, :use_ssl => false) }
    let (:httpredirection) { Net::HTTPFound.new('1.1', 302, 'Moved Temporarily') }
    let (:httpok) { Net::HTTPOK.new('1.1', 200, '') }

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

end
