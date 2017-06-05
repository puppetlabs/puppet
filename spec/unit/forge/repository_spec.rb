# encoding: utf-8
require 'spec_helper'
require 'net/http'
require 'puppet/forge/repository'
require 'puppet/forge/cache'
require 'puppet/forge/errors'

describe Puppet::Forge::Repository do
  before(:all) do
    # any local http proxy will break these tests
    ENV['http_proxy'] = nil
    ENV['HTTP_PROXY'] = nil
  end
  let(:agent) { "Test/1.0" }
  let(:repository) { Puppet::Forge::Repository.new('http://fake.com', agent) }
  let(:ssl_repository) { Puppet::Forge::Repository.new('https://fake.com', agent) }

  it "retrieve accesses the cache" do
    path = '/module/foo.tar.gz'
    repository.cache.expects(:retrieve)

    repository.retrieve(path)
  end

  it "retrieve merges forge URI and path specified" do
    host = 'http://fake.com/test'
    path = '/module/foo.tar.gz'
    uri  = [ host, path ].join('')

    repository = Puppet::Forge::Repository.new(host, agent)
    repository.cache.expects(:retrieve).with(uri)

    repository.retrieve(path)
  end

  describe "making a request" do
    before :each do
      proxy_settings_of("proxy", 1234)
    end

    it "returns the result object from the request" do
      result = "#{Object.new}"

      performs_an_http_request result do |http|
        http.expects(:request).with(responds_with(:path, "the_path"))
      end

      expect(repository.make_http_request("the_path")).to eq(result)
    end

    it "merges forge URI and path specified" do
      result = "#{Object.new}"

      performs_an_http_request result do |http|
        http.expects(:request).with(responds_with(:path, "/test/the_path/"))
      end

      repository = Puppet::Forge::Repository.new('http://fake.com/test', agent)
      expect(repository.make_http_request("/the_path/")).to eq(result)
    end

    it "handles trailing slashes when merging URI and path" do
      result = "#{Object.new}"

      performs_an_http_request result do |http|
        http.expects(:request).with(responds_with(:path, "/test/the_path"))
      end

      repository = Puppet::Forge::Repository.new('http://fake.com/test/', agent)
      expect(repository.make_http_request("/the_path")).to eq(result)
    end

    it 'returns the result object from a request with ssl' do
      result = "#{Object.new}"
      performs_an_https_request result do |http|
        http.expects(:request).with(responds_with(:path, "the_path"))
      end

      expect(ssl_repository.make_http_request("the_path")).to eq(result)
    end

    it 'return a valid exception when there is an SSL verification problem' do
      performs_an_https_request "#{Object.new}" do |http|
        http.expects(:request).with(responds_with(:path, "the_path")).raises OpenSSL::SSL::SSLError.new("certificate verify failed")
      end

      expect { ssl_repository.make_http_request("the_path") }.to raise_error Puppet::Forge::Errors::SSLVerifyError, 'Unable to verify the SSL certificate at https://fake.com'
    end

    it 'return a valid exception when there is a communication problem' do
      performs_an_http_request "#{Object.new}" do |http|
        http.expects(:request).with(responds_with(:path, "the_path")).raises SocketError
      end

      expect { repository.make_http_request("the_path") }.
        to raise_error Puppet::Forge::Errors::CommunicationError,
        'Unable to connect to the server at http://fake.com. Detail: SocketError.'
    end

    it "sets the user agent for the request" do
      path = 'the_path'

      request = repository.get_request_object(path)

      expect(request['User-Agent']).to match(/\b#{agent}\b/)
      expect(request['User-Agent']).to match(/\bPuppet\b/)
      expect(request['User-Agent']).to match(/\bRuby\b/)
    end

    it "Does not set Authorization header by default" do
      Puppet.features.stubs(:pe_license?).returns(false)
      Puppet[:forge_authorization] = nil
      request = repository.get_request_object("the_path")
      expect(request['Authorization']).to eq(nil)
    end

    it "Sets Authorization header from config" do
      token = 'bearer some token'
      Puppet[:forge_authorization] = token
      request = repository.get_request_object("the_path")
      expect(request['Authorization']).to eq(token)
    end

    it "encodes the received URI" do
      unescaped_uri = "héllo world !! ç à"
      performs_an_http_request do |http|
        http.expects(:request).with(responds_with(:path, Puppet::Util.uri_encode(unescaped_uri)))
      end

      repository.make_http_request(unescaped_uri)
    end

    def performs_an_http_request(result = nil, &block)
      proxy_args = ["proxy", 1234, nil, nil]
      mock_proxy(80, proxy_args, result, &block)
    end

    def performs_an_https_request(result = nil, &block)
      proxy_args = ["proxy", 1234, nil, nil]
      proxy = mock_proxy(443, proxy_args, result, &block)
      proxy.expects(:use_ssl=).with(true)
      proxy.expects(:cert_store=)
      proxy.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
    end

  end

  describe "making a request against an authentiated proxy" do
    before :each do
      authenticated_proxy_settings_of("proxy", 1234, 'user1', 'password')
    end

    it "returns the result object from the request" do
      result = "#{Object.new}"

      performs_an_authenticated_http_request result do |http|
        http.expects(:request).with(responds_with(:path, "the_path"))
      end

      expect(repository.make_http_request("the_path")).to eq(result)
    end

    it 'returns the result object from a request with ssl' do
      result = "#{Object.new}"
      performs_an_authenticated_https_request result do |http|
        http.expects(:request).with(responds_with(:path, "the_path"))
      end

      expect(ssl_repository.make_http_request("the_path")).to eq(result)
    end

    it 'return a valid exception when there is an SSL verification problem' do
      performs_an_authenticated_https_request "#{Object.new}" do |http|
        http.expects(:request).with(responds_with(:path, "the_path")).raises OpenSSL::SSL::SSLError.new("certificate verify failed")
      end

      expect { ssl_repository.make_http_request("the_path") }.to raise_error Puppet::Forge::Errors::SSLVerifyError, 'Unable to verify the SSL certificate at https://fake.com'
    end

    it 'return a valid exception when there is a communication problem' do
      performs_an_authenticated_http_request "#{Object.new}" do |http|
        http.expects(:request).with(responds_with(:path, "the_path")).raises SocketError
      end

      expect { repository.make_http_request("the_path") }.
        to raise_error Puppet::Forge::Errors::CommunicationError,
        'Unable to connect to the server at http://fake.com. Detail: SocketError.'
    end

    it "sets the user agent for the request" do
      path = 'the_path'

      request = repository.get_request_object(path)

      expect(request['User-Agent']).to match(/\b#{agent}\b/)
      expect(request['User-Agent']).to match(/\bPuppet\b/)
      expect(request['User-Agent']).to match(/\bRuby\b/)
    end

    it "encodes the received URI" do
      unescaped_uri = "héllo world !! ç à"
      performs_an_authenticated_http_request do |http|
        http.expects(:request).with(responds_with(:path, Puppet::Util.uri_encode(unescaped_uri)))
      end

      repository.make_http_request(unescaped_uri)
    end

    def performs_an_authenticated_http_request(result = nil, &block)
      proxy_args = ["proxy", 1234, 'user1', 'password']
      mock_proxy(80, proxy_args, result, &block)
    end

    def performs_an_authenticated_https_request(result = nil, &block)
      proxy_args = ["proxy", 1234, 'user1', 'password']
      proxy = mock_proxy(443, proxy_args, result, &block)
      proxy.expects(:use_ssl=).with(true)
      proxy.expects(:cert_store=)
      proxy.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
    end
  end

  def proxy_settings_of(host, port)
    Puppet[:http_proxy_host] = host
    Puppet[:http_proxy_port] = port
  end

  def authenticated_proxy_settings_of(host, port, user, password)
    Puppet[:http_proxy_host] = host
    Puppet[:http_proxy_port] = port
    Puppet[:http_proxy_user] = user
    Puppet[:http_proxy_password] = password
  end

  def mock_proxy(port, proxy_args, result, &block)
    http = mock("http client")
    proxy = mock("http proxy")
    proxy_class = mock("http proxy class")

    Net::HTTP.expects(:Proxy).with(*proxy_args).returns(proxy_class)
    proxy_class.expects(:new).with("fake.com", port).returns(proxy)

    proxy.expects(:open_timeout=)
    proxy.expects(:read_timeout=)

    proxy.expects(:start).yields(http).returns(result)
    yield http

    proxy
  end
end
