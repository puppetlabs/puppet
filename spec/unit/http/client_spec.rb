require 'spec_helper'
require 'webmock/rspec'
require 'puppet/http'

describe Puppet::HTTP::Client do
  let(:uri) { URI.parse('https://www.example.com') }
  let(:client) { described_class.new }

  context "when connecting" do
    it 'connects to HTTP URLs' do
      uri = URI.parse('http://www.example.com')

      client.connect(uri) do |http|
        expect(http.address).to eq('www.example.com')
        expect(http.port).to eq(80)
        expect(http).to_not be_use_ssl
      end
    end

    it 'connects to HTTPS URLs' do
      client.connect(uri) do |http|
        expect(http.address).to eq('www.example.com')
        expect(http.port).to eq(443)
        expect(http).to be_use_ssl
      end
    end

    it 'raises ConnectionError if the connection is refused' do
      allow_any_instance_of(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)

      expect {
        client.connect(uri)
      }.to raise_error(Puppet::HTTP::ConnectionError, %r{Failed to connect to https://www.example.com:})
    end
  end

  context 'after connecting' do
    def expect_http_error(cause, expected_message)
      expect {
        client.connect(uri) do |_|
          raise cause, 'whoops'
        end
      }.to raise_error(Puppet::HTTP::HTTPError, expected_message)
    end

    it 're-raises HTTPError' do
      expect_http_error(Puppet::HTTP::HTTPError, 'whoops')
    end

    it 'raises HTTPError if connection is interrupted while reading' do
      expect_http_error(EOFError, %r{Request to https://www.example.com interrupted after .* seconds})
    end

    it 'raises HTTPError if connection times out' do
      expect_http_error(Net::ReadTimeout, %r{Request to https://www.example.com timed out after .* seconds})
    end

    it 'raises HTTPError if connection fails' do
      expect_http_error(ArgumentError, %r{Request to https://www.example.com failed after .* seconds})
    end
  end

  context "when closing" do
    it "closes all connections in the pool" do
      pool = double('pool')
      expect(pool).to receive(:close)

      client = described_class.new(pool: pool)
      client.close
    end
  end

  context "for GET requests" do
    it "includes default HTTP headers" do
      stub_request(:get, uri).with(headers: {'X-Puppet-Version' => /./, 'User-Agent' => /./})

      client.get(uri)
    end

    it "stringifies keys and encodes values in the query" do
      stub_request(:get, uri).with(query: "foo=bar%3Dbaz")

      client.get(uri, params: {:foo => "bar=baz"})
    end

    it "includes custom headers" do
      stub_request(:get, uri).with(headers: { 'X-Foo' => 'Bar' })

      client.get(uri, headers: {'X-Foo' => 'Bar'})
    end

    it "returns the response" do
      stub_request(:get, uri)

      response = client.get(uri)
      expect(response).to be_an_instance_of(Puppet::HTTP::Response)
      expect(response).to be_success
      expect(response.code).to eq(200)
    end

    it "returns the entire response body" do
      stub_request(:get, uri).to_return(body: "abc")

      expect(client.get(uri).body).to eq("abc")
    end

    it "streams the response body when a block is given" do
      stub_request(:get, uri).to_return(body: "abc")

      io = StringIO.new
      client.get(uri) do |response|
        response.read_body do |data|
          io.write(data)
        end
      end

      expect(io.string).to eq("abc")
    end
  end

  context "for PUT requests" do
    it "includes default HTTP headers" do
      stub_request(:put, uri).with(headers: {'X-Puppet-Version' => /./, 'User-Agent' => /./})

      client.put(uri, content_type: 'text/plain', body: "")
    end

    it "stringifies keys and encodes values in the query" do
      stub_request(:put, "https://www.example.com").with(query: "foo=bar%3Dbaz")

      client.put(uri, params: {:foo => "bar=baz"}, content_type: 'text/plain', body: "")
    end

    it "includes custom headers" do
      stub_request(:put, "https://www.example.com").with(headers: { 'X-Foo' => 'Bar' })

      client.put(uri, headers: {'X-Foo' => 'Bar'}, content_type: 'text/plain', body: "")
    end

    it "returns the response" do
      stub_request(:put, uri)

      response = client.put(uri, content_type: 'text/plain', body: "")
      expect(response).to be_an_instance_of(Puppet::HTTP::Response)
      expect(response).to be_success
      expect(response.code).to eq(200)
    end

    it "sets content-length and content-type for the body" do
      stub_request(:put, uri).with(headers: {"Content-Length" => "5", "Content-Type" => "text/plain"})

      client.put(uri, content_type: 'text/plain', body: "hello")
    end
  end

  context "Basic Auth" do
    let(:credentials) { ['user', 'pass'] }

    it "submits credentials for GET requests" do
      stub_request(:get, uri).with(basic_auth: credentials)

      client.get(uri, user: 'user', password: 'pass')
    end

    it "submits credentials for PUT requests" do
      stub_request(:put, uri).with(basic_auth: credentials)

      client.put(uri, content_type: 'text/plain', body: "hello", user: 'user', password: 'pass')
    end

    it "returns response containing access denied" do
      stub_request(:get, uri).with(basic_auth: credentials).to_return(status: [403, "Ye Shall Not Pass"])

      response = client.get(uri, user: 'user', password: 'pass')
      expect(response.code).to eq(403)
      expect(response.reason).to eq("Ye Shall Not Pass")
      expect(response).to_not be_success
    end

    it 'omits basic auth if user is nil' do
      stub_request(:get, uri).with do |req|
        expect(req.headers).to_not include('Authorization')
      end

      client.get(uri, user: nil, password: 'pass')
    end

    it 'omits basic auth if password is nil' do
      stub_request(:get, uri).with do |req|
        expect(req.headers).to_not include('Authorization')
      end

      client.get(uri, user: 'user', password: nil)
    end
  end
end
