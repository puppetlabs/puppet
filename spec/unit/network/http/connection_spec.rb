#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http/connection'
require 'puppet_spec/validators'
require 'puppet/test_ca'

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

      it "can disable ssl using an option and ignore the verify" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => false)

        expect(conn).to_not be_use_ssl
      end

      it "can enable ssl using an option" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn).to be_use_ssl
      end

      it "ignores the ':verify' option when ssl is disabled" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => false, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn.verifier).to be_nil
      end

      it "wraps the validator in an adapter" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn.verifier).to be_a_kind_of(Puppet::SSL::VerifierAdapter)
      end

      it "should raise Puppet::Error when invalid options are specified" do
        expect { Puppet::Network::HTTP::Connection.new(host, port, :invalid_option => nil) }.to raise_error(Puppet::Error, 'Unrecognized option(s): :invalid_option')
      end

      it "accepts a verifier" do
        verifier = Puppet::SSL::Verifier.new(stub('conn'))
        conn = Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true, :verifier => verifier)

        expect(conn.verifier).to eq(verifier)
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
          Net::HTTP.any_instance.stubs(method).yields.returns(httpok)

          block_executed = false
          subject.send(method, "/foo", body) do |response|
            block_executed = true
          end
          expect(block_executed).to eq(true)
        end
      end
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

    it "should provide a useful error message when one is available and certificate validation fails", :unless => Puppet::Util::Platform.windows? do
      connection = Puppet::Network::HTTP::Connection.new(
        host, port,
        :verify => ConstantErrorValidator.new(:fails_with => 'certificate verify failed',
                                              :error_string => 'shady looking signature'))

      expect do
        connection.get('request')
      end.to raise_error(Puppet::Error, "certificate verify failed: [shady looking signature]")
    end

    it "should provide a helpful error message when hostname was not match with server certificate", :unless => Puppet::Util::Platform.windows? || RUBY_PLATFORM == 'java' do
      Puppet[:confdir] = tmpdir('conf')

      connection = Puppet::Network::HTTP::Connection.new(
      host, port,
      :verify => ConstantErrorValidator.new(
        :fails_with => 'hostname was not match with server certificate',
        :peer_certs => [Puppet::TestCa.new.generate('not_my_server',
                                                    :subject_alt_names => 'DNS:foo,DNS:bar,DNS:baz,DNS:not_my_server')[:cert]]))

      expect do
        connection.get('request')
      end.to raise_error(Puppet::Error) do |error|
        error.message =~ /\AServer hostname 'my_server' did not match server certificate; expected one of (.+)/
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

    it "should check all peer certificates for upcoming expiration", :unless => Puppet::Util::Platform.windows? || RUBY_PLATFORM == 'java' do
      Puppet[:confdir] = tmpdir('conf')
      cert = Puppet::TestCa.new.generate('server',
                                         :subject_alt_names => 'DNS:foo,DNS:bar,DNS:baz,DNS:server')[:cert]

      connection = Puppet::Network::HTTP::Connection.new(
        host, port,
        :verify => NoProblemsValidator.new(cert))

      Net::HTTP.any_instance.stubs(:start)
      Net::HTTP.any_instance.stubs(:request).returns(httpok)
      Net::HTTP.any_instance.stubs(:finish)
      Puppet::Network::HTTP::Pool.any_instance.stubs(:setsockopts)

      connection.get('request')
    end
  end

  context "when using single use HTTPS connections", :unless => RUBY_PLATFORM == 'java' do
    it_behaves_like 'ssl verifier' do
    end
  end

  context "when using persistent HTTPS connections", :unless => RUBY_PLATFORM == 'java' do
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

  context "when response indicates an overloaded server" do
    let(:http) { stub('http') }
    let(:site) { Puppet::Network::HTTP::Site.new('http', 'my_server', 8140) }
    let(:verify) { Puppet::SSL::Validator.no_validator }
    let(:httpunavailable) { Net::HTTPServiceUnavailable.new('1.1', 503, 'Service Unavailable') }

    subject { Puppet::Network::HTTP::Connection.new(site.host, site.port, :use_ssl => false, :verify => verify) }

    context "when parsing Retry-After headers" do
      # Private method. Create a reference that can be called by tests.
      let(:header_parser) { subject.method(:parse_retry_after_header) }

      it "returns 0 when parsing a RFC 2822 date that has passed" do
        test_date = 'Wed, 13 Apr 2005 15:18:05 GMT'

        expect(header_parser.call(test_date)).to eq(0)
      end
    end

    it "should return a 503 response if Retry-After is not set" do
      http.stubs(:request).returns(httpunavailable)

      pool = Puppet.lookup(:http_pool)
      pool.expects(:with_connection).with(site, anything).yields(http)

      result = subject.get('/foo')

      expect(result.code).to eq(503)
    end

    it "should return a 503 response if Retry-After is not convertible to an Integer or RFC 2822 Date" do
      httpunavailable['Retry-After'] = 'foo'
      http.stubs(:request).returns(httpunavailable)

      pool = Puppet.lookup(:http_pool)
      pool.expects(:with_connection).with(site, anything).yields(http)

      result = subject.get('/foo')

      expect(result.code).to eq(503)
    end

    it "should sleep and retry if Retry-After is an Integer" do
      httpunavailable['Retry-After'] = '42'
      http.stubs(:request).returns(httpunavailable).then.returns(httpok)

      pool = Puppet.lookup(:http_pool)
      pool.expects(:with_connection).with(site, anything).twice.yields(http)

      ::Kernel.expects(:sleep).with(42)

      result = subject.get('/foo')

      expect(result.code).to eq(200)
    end

    it "should sleep and retry if Retry-After is an RFC 2822 Date" do
      httpunavailable['Retry-After'] = 'Wed, 13 Apr 2005 15:18:05 GMT'
      http.stubs(:request).returns(httpunavailable).then.returns(httpok)

      now = DateTime.new(2005, 4, 13, 8, 17, 5, '-07:00')
      DateTime.stubs(:now).returns(now)

      pool = Puppet.lookup(:http_pool)
      pool.expects(:with_connection).with(site, anything).twice.yields(http)

      ::Kernel.expects(:sleep).with(60)

      result = subject.get('/foo')

      expect(result.code).to eq(200)
    end

    it "should sleep for no more than the Puppet runinterval" do
      httpunavailable['Retry-After'] = '60'
      http.stubs(:request).returns(httpunavailable).then.returns(httpok)
      Puppet[:runinterval] = 30

      pool = Puppet.lookup(:http_pool)
      pool.expects(:with_connection).with(site, anything).twice.yields(http)

      ::Kernel.expects(:sleep).with(30)

      subject.get('/foo')
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

  it "sets HTTP User-Agent header" do
    puppet_ua = "Puppet/#{Puppet.version} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"

    Net::HTTP.any_instance.expects(:request).with do |request|
      expect(request['User-Agent']).to eq(puppet_ua)
    end.returns(httpok)

    subject.get('/path')
  end
end
