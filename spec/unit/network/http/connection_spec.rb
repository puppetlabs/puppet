require 'spec_helper'
require 'puppet/network/http/connection'
require 'puppet/test_ca'

describe Puppet::Network::HTTP::Connection do
  let (:host) { "me.example.com" }
  let (:port) { 8140 }
  let (:url) { "https://#{host}:#{port}/foo" }

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
      retry_after('foo')

      result = subject.get('/foo')
      expect(result.code).to eq("503")
    end

    it "should close the connection before sleeping" do
      retry_after('42')

      http1 = Net::HTTP.new(host, port)
      http1.use_ssl = true
      allow(http1).to receive(:started?).and_return(true)

      http2 = Net::HTTP.new(host, port)
      http2.use_ssl = true
      allow(http1).to receive(:started?).and_return(true)

      # The "with_connection" method is required to yield started connections
      pool = Puppet.lookup(:http_pool)
      allow(pool).to receive(:with_connection).and_yield(http1).and_yield(http2)

      expect(http1).to receive(:finish).ordered
      expect(::Kernel).to receive(:sleep).with(42).ordered

      subject.get('/foo')
    end

    it "should sleep and retry if Retry-After is an Integer" do
      retry_after('42')

      expect(::Kernel).to receive(:sleep).with(42)

      result = subject.get('/foo')
      expect(result.code).to eq("200")
    end

    it "should sleep and retry if Retry-After is an RFC 2822 Date" do
      retry_after('Wed, 13 Apr 2005 15:18:05 GMT')

      now = DateTime.new(2005, 4, 13, 8, 17, 5, '-07:00')
      allow(DateTime).to receive(:now).and_return(now)

      expect(::Kernel).to receive(:sleep).with(60)

      result = subject.get('/foo')
      expect(result.code).to eq("200")
    end

    it "should sleep for no more than the Puppet runinterval" do
      retry_after('60')

      Puppet[:runinterval] = 30

      expect(::Kernel).to receive(:sleep).with(30)

      subject.get('/foo')
    end

    it "should sleep for 0 seconds if the RFC 2822 date has past" do
      retry_after('Wed, 13 Apr 2005 15:18:05 GMT')

      expect(::Kernel).to receive(:sleep).with(0)

      subject.get('/foo')
    end
  end

  context "basic auth" do
    let(:auth) { { :user => 'user', :password => 'password' } }
    let(:creds) { [ 'user', 'password'] }

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

      subject.put('/foo', 'data', nil, :basic_auth => auth)
    end
  end

  it "sets HTTP User-Agent header" do
    puppet_ua = "Puppet/#{Puppet.version} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"
    stub_request(:get, url).with(headers: { 'User-Agent' => puppet_ua })

    subject.get('/foo')
  end

  describe 'connection request errors' do
    it "logs and raises generic http errors" do
      generic_error = Net::HTTPError.new('generic error', double("response"))
      stub_request(:get, url).to_raise(generic_error)

      expect(Puppet).to receive(:log_exception).with(anything, /^.*failed: generic error$/)
      expect { subject.get('/foo') }.to raise_error(generic_error)
    end

    it "logs and raises timeout errors" do
      timeout_error = Timeout::Error.new
      stub_request(:get, url).to_raise(timeout_error)

      expect(Puppet).to receive(:log_exception).with(anything, /^.*timed out after .* seconds$/)
      expect { subject.get('/foo') }.to raise_error(timeout_error)
    end

    it "logs and raises eof errors" do
      eof_error = EOFError
      stub_request(:get, url).to_raise(eof_error)

      expect(Puppet).to receive(:log_exception).with(anything, /^.*interrupted after .* seconds$/)
      expect { subject.get('/foo') }.to raise_error(eof_error)
    end
  end
end
