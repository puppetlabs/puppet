require 'spec_helper'
require 'puppet/network/http/connection'
require 'puppet_spec/validators'
require 'puppet/test_ca'

describe Puppet::Network::HTTP::Connection do
<<<<<<< HEAD
  let (:host) { "me" }
  let (:port) { 54321 }
=======
  let (:host) { "me.example.com" }
  let (:port) { 8140 }
  let (:url) { "https://#{host}:#{port}/foo" }

>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7
  subject { Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator) }

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
<<<<<<< HEAD
      end

      it "wraps the validator in an adapter" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn.verifier).to be_a_kind_of(Puppet::SSL::VerifierAdapter)
      end

      it "should raise Puppet::Error when invalid options are specified" do
        expect { Puppet::Network::HTTP::Connection.new(host, port, :invalid_option => nil) }.to raise_error(Puppet::Error, 'Unrecognized option(s): :invalid_option')
      end

      it "accepts a verifier" do
        verifier = Puppet::SSL::Verifier.new('fqdn', double('ssl_context'))
        conn = Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true, :verifier => verifier)

        expect(conn.verifier).to eq(verifier)
      end

      it "raises if the wrong verifier class is specified" do
        expect {
          Puppet::Network::HTTP::Connection.new(host, port, :verifier => Puppet::SSL::Validator.default_validator)
        }.to raise_error(ArgumentError,
                         "Expected an instance of Puppet::SSL::Verifier but was passed a Puppet::SSL::Validator::DefaultValidator")
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
          allow_any_instance_of(Net::HTTP).to receive(method) do |_, *_, &block|
            block.call()
            httpok
          end

          block_executed = false
          subject.send(method, "/foo", body) do |response|
            block_executed = true
          end
          expect(block_executed).to eq(true)
        end
=======
      end

      it "wraps the validator in an adapter" do
        conn = Puppet::Network::HTTP::Connection.new(host, port, :verify => Puppet::SSL::Validator.no_validator)

        expect(conn.verifier).to be_a_kind_of(Puppet::SSL::VerifierAdapter)
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7
      end

<<<<<<< HEAD
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
=======
      it "should raise Puppet::Error when invalid options are specified" do
        expect { Puppet::Network::HTTP::Connection.new(host, port, :invalid_option => nil) }.to raise_error(Puppet::Error, 'Unrecognized option(s): :invalid_option')
      end

      it "accepts a verifier" do
        verifier = Puppet::SSL::Verifier.new('fqdn', double('ssl_context'))
        conn = Puppet::Network::HTTP::Connection.new(host, port, :use_ssl => true, :verifier => verifier)

        expect(conn.verifier).to eq(verifier)
      end

      it "raises if the wrong verifier class is specified" do
        expect {
          Puppet::Network::HTTP::Connection.new(host, port, :verifier => Puppet::SSL::Validator.default_validator)
        }.to raise_error(ArgumentError,
                         "Expected an instance of Puppet::SSL::Verifier but was passed a Puppet::SSL::Validator::DefaultValidator")
      end
    end
  end

  context "when handling requests" do
    it 'yields the response when request_get is called' do
      stub_request(:get, url)

      expect { |b|
        subject.request_get('/foo', {}, &b)
      }.to yield_with_args(Net::HTTPResponse)
    end

    it 'yields the response when request_head is called' do
      stub_request(:head, url)

      expect { |b|
        subject.request_head('/foo', {}, &b)
      }.to yield_with_args(Net::HTTPResponse)
    end

    it 'yields the response when request_post is called' do
      stub_request(:post, url)

      expect { |b|
        subject.request_post('/foo', "param: value", &b)
      }.to yield_with_args(Net::HTTPResponse)
    end
  end

  context "when response is a redirect" do
    def create_connection(options = {})
      options[:use_ssl] = false
      options[:verify] = Puppet::SSL::Validator.no_validator
      Puppet::Network::HTTP::Connection.new(host, port, options)
    end

    def redirect_to(url)
      { status: 302, headers: { 'Location' => url } }
    end

    it "should follow the redirect to the final resource location" do
      stub_request(:get, "http://me.example.com:8140/foo").to_return(redirect_to("http://me.example.com:8140/bar"))
      stub_request(:get, "http://me.example.com:8140/bar").to_return(status: 200)

      create_connection.get('/foo')
    end

    def expects_limit_exceeded(conn)
      expect {
        conn.get('/')
      }.to raise_error(Puppet::Network::HTTP::RedirectionLimitExceededException)
    end

    it "should not follow any redirects when the limit is 0" do
      stub_request(:get, "http://me.example.com:8140/").to_return(redirect_to("http://me.example.com:8140/foo"))

      conn = create_connection(:redirect_limit => 0)
      expects_limit_exceeded(conn)
    end

    it "should follow the redirect once" do
      stub_request(:get, "http://me.example.com:8140/").to_return(redirect_to("http://me.example.com:8140/foo"))
      stub_request(:get, "http://me.example.com:8140/foo").to_return(redirect_to("http://me.example.com:8140/bar"))

      conn = create_connection(:redirect_limit => 1)
      expects_limit_exceeded(conn)
    end

    it "should raise an exception when the redirect limit is exceeded" do
      stub_request(:get, "http://me.example.com:8140/").to_return(redirect_to("http://me.example.com:8140/foo"))
      stub_request(:get, "http://me.example.com:8140/foo").to_return(redirect_to("http://me.example.com:8140/bar"))
      stub_request(:get, "http://me.example.com:8140/bar").to_return(redirect_to("http://me.example.com:8140/baz"))
      stub_request(:get, "http://me.example.com:8140/baz").to_return(redirect_to("http://me.example.com:8140/qux"))

      conn = create_connection(:redirect_limit => 3)
      expects_limit_exceeded(conn)
    end
  end

  context "when response indicates an overloaded server" do
    def retry_after(datetime)
      stub_request(:get, url)
        .to_return(status: [503, 'Service Unavailable'], headers: {'Retry-After' => datetime}).then
        .to_return(status: 200)
    end

    it "should return a 503 response if Retry-After is not set" do
      stub_request(:get, url).to_return(status: [503, 'Service Unavailable'])

      result = subject.get('/foo')
      expect(result.code).to eq("503")
    end

    it "should return a 503 response if Retry-After is not convertible to an Integer or RFC 2822 Date" do
      stub_request(:get, url).to_return(status: [503, 'Service Unavailable'], headers: {'Retry-After' => 'foo'})
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7

      result = subject.get('/foo')
      expect(result.code).to eq("503")
    end

<<<<<<< HEAD
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
=======
    it "should sleep and retry if Retry-After is an Integer" do
      retry_after('42')

      expect(::Kernel).to receive(:sleep).with(42)

      result = subject.get('/foo')
      expect(result.code).to eq("200")
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7
    end

    it "should sleep and retry if Retry-After is an RFC 2822 Date" do
      retry_after('Wed, 13 Apr 2005 15:18:05 GMT')

      now = DateTime.new(2005, 4, 13, 8, 17, 5, '-07:00')
      allow(DateTime).to receive(:now).and_return(now)

<<<<<<< HEAD
      pool = expects_redirection(conn)
      expect(pool).not_to receive(:with_connection).with(other_site, anything)
=======
      expect(::Kernel).to receive(:sleep).with(60)
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7

      result = subject.get('/foo')
      expect(result.code).to eq("200")
    end

    it "should sleep for no more than the Puppet runinterval" do
      retry_after('60')
      Puppet[:runinterval] = 30

<<<<<<< HEAD
      pool = expects_redirection(conn)
      expect(pool).to receive(:with_connection).with(other_site, anything).once
=======
      expect(::Kernel).to receive(:sleep).with(30)
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7

      subject.get('/foo')
    end

    it "should sleep for 0 seconds if the RFC 2822 date has past" do
      retry_after('Wed, 13 Apr 2005 15:18:05 GMT')

<<<<<<< HEAD
      pool = expects_redirection(conn)
      expect(pool).to receive(:with_connection).with(other_site, anything).exactly(3).times
=======
      expect(::Kernel).to receive(:sleep).with(0)
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7

      subject.get('/foo')
    end
  end

<<<<<<< HEAD
  context "when response indicates an overloaded server" do
    let(:http) { double('http') }
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

      result = subject.get('/foo')

      expect(result.code).to eq(503)
    end

    it "should return a 503 response if Retry-After is not convertible to an Integer or RFC 2822 Date" do
      httpunavailable['Retry-After'] = 'foo'
      allow(http).to receive(:request).and_return(httpunavailable)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).and_yield(http)

      result = subject.get('/foo')

      expect(result.code).to eq(503)
    end

    it "should sleep and retry if Retry-After is an Integer" do
      httpunavailable['Retry-After'] = '42'
      allow(http).to receive(:request).and_return(httpunavailable, httpok)

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).twice.and_yield(http)

      expect(::Kernel).to receive(:sleep).with(42)

      result = subject.get('/foo')

      expect(result.code).to eq(200)
    end

    it "should sleep and retry if Retry-After is an RFC 2822 Date" do
      httpunavailable['Retry-After'] = 'Wed, 13 Apr 2005 15:18:05 GMT'
      allow(http).to receive(:request).and_return(httpunavailable, httpok)

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
      Puppet[:runinterval] = 30

      pool = Puppet.lookup(:http_pool)
      expect(pool).to receive(:with_connection).with(site, anything).twice.and_yield(http)

      expect(::Kernel).to receive(:sleep).with(30)

      subject.get('/foo')
    end
  end

  it "allows setting basic auth on get requests" do
    expect_request_with_basic_auth
=======
  context "basic auth" do
    let(:auth) { { :user => 'user', :password => 'password' } }
    let(:creds) { [ 'user', 'password'] }
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7

    it "is allowed in get requests" do
      stub_request(:get, url).with(basic_auth: creds)

      subject.get('/foo', nil, :basic_auth => auth)
    end

    it "is allowed in post requests" do
      stub_request(:post, url).with(basic_auth: creds)

      subject.post('/foo', 'data', nil, :basic_auth => auth)
    end

    it "is allowed in head requests" do
      stub_request(:head, url).with(basic_auth: creds)

      subject.head('/foo', nil, :basic_auth => auth)
    end

    it "is allowed in delete requests" do
      stub_request(:delete, url).with(basic_auth: creds)

      subject.delete('/foo', nil, :basic_auth => auth)
    end

    it "is allowed in put requests" do
      stub_request(:put, url).with(basic_auth: creds)

<<<<<<< HEAD
  def expect_request_with_basic_auth
    expect_any_instance_of(Net::HTTP).to receive(:request) do |_, request|
      expect(request['authorization']).to match(/^Basic/)
    end.and_return(httpok)
=======
      subject.put('/foo', 'data', nil, :basic_auth => auth)
    end
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7
  end

  it "sets HTTP User-Agent header" do
    puppet_ua = "Puppet/#{Puppet.version} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"
    stub_request(:get, url).with(headers: { 'User-Agent' => puppet_ua })

<<<<<<< HEAD
    expect_any_instance_of(Net::HTTP).to receive(:request) do |_, request|
      expect(request['User-Agent']).to eq(puppet_ua)
    end.and_return(httpok)

    subject.get('/path')
=======
    subject.get('/foo')
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7
  end
end
