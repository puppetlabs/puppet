#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http/connection'

describe Puppet::Network::HTTP::Connection do

  let (:host) { "me" }
  let (:port) { 54321 }
  subject { Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator) }
  let (:httpok) { Net::HTTPOK.new('1.1', 200, '') }

  context "when providing HTTP connections" do
    context "when initializing http instances" do
      it "should return an http instance created with the passed host and port" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn.address).to eq(host)
        expect(conn.port).to eq(port)
      end

      it "should enable ssl on the http instance by default" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn).to be_use_ssl
      end

      it "can disable ssl using an option" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => false, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn).to_not be_use_ssl
      end

      it "can enable ssl using an option" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn).to be_use_ssl
      end

      it "should raise Puppet::Error when invalid options are specified" do
        expect { Puppet::Network::HTTP::Connection.new(host, port, :invalid_option => nil) }.to raise_error(Puppet::Error, 'Unrecognized option(s): :invalid_option')
      end
    end
  end

  context "when handling requests", :vcr do
    let (:host) { "my-server" }
    let (:port) { 8140 }
    let (:subject) { Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => false, :verify => Puppet::SSL::Validator.no_validator) }

    { :request_get  => {},
      :request_head => {},
      :request_post => "param: value" }.each do |method,body|
      context "##{method}" do
        it "should yield to the block" do
          block_executed = false
          subject.send(method, "/foo", body) do |response|
            block_executed = true
          end
          expect(block_executed).to eq(true)
        end
      end
    end
  end

  class ConstantErrorValidator
    def initialize(args)
      @fails_with = args[:fails_with]
      @error_string = args[:error_string] || ""
      @peer_certs = args[:peer_certs] || []
    end

    def setup_connection(connection)
      connection.stubs(:start).raises(OpenSSL::SSL::SSLError.new(@fails_with))
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

  shared_examples_for 'ssl verifier' do
    include PuppetSpec::Files

    let (:host) { "my_server" }
    let (:port) { 8140 }

    before :all do
      WebMock.disable!
    end

    after :all do
      WebMock.enable!
    end

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
        expect($1.split(', ')).to match_array(%w[DNS:foo DNS:bar DNS:baz DNS:not_my_server not_my_server])
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

      Net::HTTP.any_instance.stubs(:start)
      Net::HTTP.any_instance.stubs(:request).returns(httpok)
      Puppet::Network::HTTP::Pool.any_instance.stubs(:setsockopts)

      connection.get('request')
    end
  end

  context "when using single use HTTPS connections" do
    it_behaves_like 'ssl verifier' do
    end
  end

  context "when using persistent HTTPS connections" do
    around :each do |example|
      pool = Puppet::Network::HTTP::Pool.new
      Puppet.override(:http_pool => pool) do
        example.run
      end
      pool.close
    end

    it_behaves_like 'ssl verifier' do
    end
  end

  context "when response is a redirect" do
    let (:site)       { Puppet::Network::HTTP::Site.new('http', 'my_server', 8140) }
    let (:other_site) { Puppet::Network::HTTP::Site.new('http', 'redirected', 9292) }
    let (:other_path) { "other-path" }
    let (:verify) { Puppet::SSL::Validator.no_validator }
    let (:subject) { Puppet::Network::HTTP::Connection.new(site.host, site.port, :use_ssl => false, :verify => verify) }
    let (:httpredirection) do
      response = Net::HTTPFound.new('1.1', 302, 'Moved Temporarily')
      response['location'] = "#{other_site.addr}/#{other_path}"
      response.stubs(:read_body).returns("This resource has moved")
      response
    end

    def create_connection(site, options)
      options[:use_ssl] = site.use_ssl?
      Puppet::Network::HTTP::Connection.new(site.host, site.port, options)
    end

    it "should redirect to the final resource location" do
      http = stub('http')
      http.stubs(:request).returns(httpredirection).then.returns(httpok)

      seq = sequence('redirection')
      pool = Puppet.lookup(:http_pool)
      pool.expects(:with_connection).with(site, anything).yields(http).in_sequence(seq)
      pool.expects(:with_connection).with(other_site, anything).yields(http).in_sequence(seq)

      conn = create_connection(site, :verify => verify)
      conn.get('/foo')
    end

    def expects_redirection(conn, &block)
      http = stub('http')
      http.stubs(:request).returns(httpredirection)

      pool = Puppet.lookup(:http_pool)
      pool.expects(:with_connection).with(site, anything).yields(http)
      pool
    end

    def expects_limit_exceeded(conn)
      expect {
        conn.get('/')
      }.to raise_error(Puppet::Network::HTTP::RedirectionLimitExceededException)
    end

    it "should not redirect when the limit is 0" do
      conn = create_connection(site, :verify => verify, :redirect_limit => 0)

      pool = expects_redirection(conn)
      pool.expects(:with_connection).with(other_site, anything).never

      expects_limit_exceeded(conn)
    end

    it "should redirect only once" do
      conn = create_connection(site, :verify => verify, :redirect_limit => 1)

      pool = expects_redirection(conn)
      pool.expects(:with_connection).with(other_site, anything).once

      expects_limit_exceeded(conn)
    end

    it "should raise an exception when the redirect limit is exceeded" do
      conn = create_connection(site, :verify => verify, :redirect_limit => 3)

      pool = expects_redirection(conn)
      pool.expects(:with_connection).with(other_site, anything).times(3)

      expects_limit_exceeded(conn)
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
