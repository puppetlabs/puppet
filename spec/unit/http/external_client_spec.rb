require 'spec_helper'
require 'puppet/http'

# Simple "external" client to make get & post requests. This is used
# to test the old HTTP API, such as requiring use_ssl and basic_auth
# to be passed as options.
class Puppet::HTTP::TestExternal
  def initialize(host, port, options = {})
    @host = host
    @port = port
    @options = options
    @factory = Puppet::Network::HTTP::Factory.new
  end

  def get(path, headers = {}, options = {})
    request = Net::HTTP::Get.new(path, headers)
    do_request(request, options)
  end

  def post(path, data, headers = nil, options = {})
    request = Net::HTTP::Post.new(path, headers)
    do_request(request, options)
  end

  def do_request(request, options)
    if options[:basic_auth]
      request.basic_auth(options[:basic_auth][:user], options[:basic_auth][:password])
    end

    site = Puppet::Network::HTTP::Site.new(@options[:use_ssl] ? 'https' : 'http', @host, @port)
    http = @factory.create_connection(site)
    http.start
    begin
      http.request(request)
    ensure
      http.finish
    end
  end
end

describe Puppet::HTTP::ExternalClient do
  let(:uri) { URI.parse('https://www.example.com') }
  let(:http_client_class) { Puppet::HTTP::TestExternal }
  let(:client) { described_class.new(http_client_class) }
  let(:credentials) { ['user', 'pass'] }

  context "for GET requests" do
    it "stringifies keys and encodes values in the query" do
      stub_request(:get, uri).with(query: "foo=bar%3Dbaz")

      client.get(uri, params: {:foo => "bar=baz"})
    end

    it "fails if a user passes in an invalid param type" do
      environment = Puppet::Node::Environment.create(:testing, [])

      expect{client.get(uri, params: {environment: environment})}.to raise_error(Puppet::HTTP::SerializationError, /HTTP REST queries cannot handle values of type/)
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

    context 'when connecting' do
      it 'accepts an ssl context' do
        stub_request(:get, uri).to_return(body: "abc")

        other_context = Puppet::SSL::SSLContext.new

        client.get(uri, options: {ssl_context: other_context})
      end

      it 'accepts include_system_store' do
        stub_request(:get, uri).to_return(body: "abc")

        client.get(uri, options: {include_system_store: true})
      end
    end
  end

  context "for POST requests" do
    it "stringifies keys and encodes values in the query" do
      stub_request(:post, "https://www.example.com").with(query: "foo=bar%3Dbaz")

      client.post(uri, "", params: {:foo => "bar=baz"}, headers: {'Content-Type' => 'text/plain'})
    end

    it "returns the response" do
      stub_request(:post, uri)

      response = client.post(uri, "", headers: {'Content-Type' => 'text/plain'})
      expect(response).to be_an_instance_of(Puppet::HTTP::Response)
      expect(response).to be_success
      expect(response.code).to eq(200)
    end

    it "sets content-type for the body" do
      stub_request(:post, uri).with(headers: {"Content-Type" => "text/plain"})

      client.post(uri, "hello", headers: {'Content-Type' => 'text/plain'})
    end

    it "streams the response body when a block is given" do
      stub_request(:post, uri).to_return(body: "abc")

      io = StringIO.new
      client.post(uri, "", headers: {'Content-Type' => 'text/plain'}) do |response|
        response.read_body do |data|
          io.write(data)
        end
      end

      expect(io.string).to eq("abc")
    end

    it 'raises an ArgumentError if `body` is missing' do
      expect {
        client.post(uri, nil, headers: {'Content-Type' => 'text/plain'})
      }.to raise_error(ArgumentError, /'post' requires a string 'body' argument/)
    end

    context 'when connecting' do
      it 'accepts an ssl context' do
        stub_request(:post, uri)

        other_context = Puppet::SSL::SSLContext.new

        client.post(uri, "", headers: {'Content-Type' => 'text/plain'}, options: {ssl_context: other_context})
      end

      it 'accepts include_system_store' do
        stub_request(:post, uri)

        client.post(uri, "", headers: {'Content-Type' => 'text/plain'}, options: {include_system_store: true})
      end
    end
  end

  context "Basic Auth" do
    it "submits credentials for GET requests" do
      stub_request(:get, uri).with(basic_auth: credentials)

      client.get(uri, options: {basic_auth: {user: 'user', password: 'pass'}})
    end

    it "submits credentials for POST requests" do
      stub_request(:post, uri).with(basic_auth: credentials)

      client.post(uri, "", options: {content_type: 'text/plain', basic_auth: {user: 'user', password: 'pass'}})
    end

    it "returns response containing access denied" do
      stub_request(:get, uri).with(basic_auth: credentials).to_return(status: [403, "Ye Shall Not Pass"])

      response = client.get(uri, options: { basic_auth: {user: 'user', password: 'pass'}})
      expect(response.code).to eq(403)
      expect(response.reason).to eq("Ye Shall Not Pass")
      expect(response).to_not be_success
    end

    it 'includes basic auth if user is nil' do
      stub_request(:get, uri).with do |req|
        expect(req.headers).to include('Authorization')
      end

      client.get(uri, options: {basic_auth: {user: nil, password: 'pass'}})
    end

    it 'includes basic auth if password is nil' do
      stub_request(:get, uri).with do |req|
        expect(req.headers).to include('Authorization')
      end

      client.get(uri, options: {basic_auth: {user: 'user', password: nil}})
    end
  end
end
