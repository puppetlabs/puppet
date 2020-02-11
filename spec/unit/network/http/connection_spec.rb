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

  context "when response is a redirect" do
    let (:site)       { Puppet::Network::HTTP::Site.new('http', 'my_server', 8140) }
    let (:other_site) { Puppet::Network::HTTP::Site.new('http', 'redirected', 9292) }
    let (:other_path) { "other-path" }
    let (:verify) { Puppet::SSL::Validator.no_validator }
    let (:subject) { Puppet::Network::HTTP::Connection.new(site.host, site.port, :use_ssl => false, :verify => verify) }
    let (:httpredirection) do
      response = Net::HTTPFound.new('1.1', 302, 'Moved Temporarily')
      response['location'] = "#{other_site.addr}/#{other_path}"
      allow(response).to receive(:read_body).and_return("This resource has moved")
      response
    end

    def create_connection(site, options)
      options[:use_ssl] = site.use_ssl?
      Puppet::Network::HTTP::Connection.new(site.host, site.port, options)
    end

    it "should redirect to the final resource location" do
      http = double('http')
      allow(http).to receive(:request).and_return(httpredirection, httpok)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).and_yield(http).ordered
      expect(pool).to receive(:with_connection).with(other_site, anything).and_yield(http).ordered

      conn = create_connection(site, :verify => verify)
      conn.get('/foo')
    end

    def expects_redirection(conn, &block)
      http = double('http')
      allow(http).to receive(:request).and_return(httpredirection)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).and_yield(http)
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
      expect(pool).not_to receive(:with_connection).with(other_site, anything)

      expects_limit_exceeded(conn)
    end

    it "should redirect only once" do
      conn = create_connection(site, :verify => verify, :redirect_limit => 1)

      pool = expects_redirection(conn)
      expect(pool).to receive(:with_connection).with(other_site, anything).once

      expects_limit_exceeded(conn)
    end

    it "should raise an exception when the redirect limit is exceeded" do
      conn = create_connection(site, :verify => verify, :redirect_limit => 3)

      pool = expects_redirection(conn)
      expect(pool).to receive(:with_connection).with(other_site, anything).exactly(3).times

      expects_limit_exceeded(conn)
    end
  end

  context "when response indicates an overloaded server" do
    let(:http) { double('http', :started? => true) }
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
      allow(http).to receive(:request).and_return(httpunavailable)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).and_yield(http)
      allow(http).to receive(:finish)

      result = subject.get('/foo')

      expect(result.code).to eq(503)
    end

    it "should return a 503 response if Retry-After is not convertible to an Integer or RFC 2822 Date" do
      httpunavailable['Retry-After'] = 'foo'
      allow(http).to receive(:request).and_return(httpunavailable)
      allow(http).to receive(:finish)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).and_yield(http)

      result = subject.get('/foo')

      expect(result.code).to eq(503)
    end

    it "should close the connection before sleeping" do
      allow(http).to receive(:request).and_return(httpunavailable, httpok)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).and_yield(http)

      expect(http).to receive(:finish)

      subject.get('/foo')
    end

    it "should sleep and retry if Retry-After is an Integer" do
      httpunavailable['Retry-After'] = '42'
      allow(http).to receive(:request).and_return(httpunavailable, httpok)
      allow(http).to receive(:finish)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).twice.and_yield(http)

      expect(::Kernel).to receive(:sleep).with(42)

      result = subject.get('/foo')

      expect(result.code).to eq(200)
    end

    it "should sleep and retry if Retry-After is an RFC 2822 Date" do
      httpunavailable['Retry-After'] = 'Wed, 13 Apr 2005 15:18:05 GMT'
      allow(http).to receive(:request).and_return(httpunavailable, httpok)
      allow(http).to receive(:finish)

      now = DateTime.new(2005, 4, 13, 8, 17, 5, '-07:00')
      allow(DateTime).to receive(:now).and_return(now)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).twice.and_yield(http)

      expect(::Kernel).to receive(:sleep).with(60)

      result = subject.get('/foo')

      expect(result.code).to eq(200)
    end

    it "should sleep for no more than the Puppet runinterval" do
      httpunavailable['Retry-After'] = '60'
      allow(http).to receive(:request).and_return(httpunavailable, httpok)
      allow(http).to receive(:finish)
      Puppet[:runinterval] = 30

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).twice.and_yield(http)

      expect(::Kernel).to receive(:sleep).with(30)

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
    expect_any_instance_of(Net::HTTP).to receive(:request) do |_, request|
      expect(request['authorization']).to match(/^Basic/)
    end.and_return(httpok)
  end

  it "sets HTTP User-Agent header" do
    puppet_ua = "Puppet/#{Puppet.version} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"

    expect_any_instance_of(Net::HTTP).to receive(:request) do |_, request|
      expect(request['User-Agent']).to eq(puppet_ua)
    end.and_return(httpok)

    subject.get('/path')
  end

  describe 'connection request errors' do
    it "logs and raises generic http errors" do
      generic_error = Net::HTTPError.new('generic error', double("response"))
      expect_any_instance_of(Net::HTTP).to receive(:request).and_raise(generic_error)

      expect(Puppet).to receive(:log_exception).with(anything, /^.*failed: generic error$/)
      expect { subject.get('/foo') }.to raise_error(generic_error)
    end

    it "logs and raises timeout errors" do
      timeout_error = Timeout::Error.new
      expect_any_instance_of(Net::HTTP).to receive(:request).and_raise(timeout_error)

      expect(Puppet).to receive(:log_exception).with(anything, /^.*timed out after .* seconds$/)
      expect { subject.get('/foo') }.to raise_error(timeout_error)
    end

    it "logs and raises eof errors" do
      eof_error = EOFError
      expect_any_instance_of(Net::HTTP).to receive(:request).and_raise(eof_error)

      expect(Puppet).to receive(:log_exception).with(anything, /^.*interrupted after .* seconds$/)
      expect { subject.get('/foo') }.to raise_error(eof_error)
    end
  end
end
