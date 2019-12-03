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

  it "retrieve accesses the cache" do
    path = '/module/foo.tar.gz'
    expect(repository.cache).to receive(:retrieve)

    repository.retrieve(path)
  end

  it "retrieve merges forge URI and path specified" do
    host = 'http://fake.com/test'
    path = '/module/foo.tar.gz'
    uri  = [ host, path ].join('')

    repository = Puppet::Forge::Repository.new(host, agent)
    expect(repository.cache).to receive(:retrieve).with(uri)

    repository.retrieve(path)
  end

  describe "making a request" do
    let(:uri) { "http://fake.com/the_path" }

    it "returns the response object from the request" do
      stub_request(:get, uri)

      expect(repository.make_http_request("/the_path")).to be_a_kind_of(Puppet::HTTP::Response)
    end

    it "requires path to have a leading slash" do
      expect {
        repository.make_http_request("the_path")
      }.to raise_error(ArgumentError, 'Path must start with forward slash')
    end

    it "merges forge URI and path specified" do
      stub_request(:get, "http://fake.com/test/the_path/")

      repository = Puppet::Forge::Repository.new('http://fake.com/test', agent)
      repository.make_http_request("/the_path/")
    end

    it "handles trailing slashes when merging URI and path" do
      stub_request(:get, "http://fake.com/test/the_path")

      repository = Puppet::Forge::Repository.new('http://fake.com/test/', agent)
      repository.make_http_request("/the_path")
    end

    it 'return a valid exception when there is a communication problem' do
      stub_request(:get, uri).to_raise(SocketError.new('getaddrinfo: Name or service not known'))

      expect {
        repository.make_http_request("/the_path")
      }.to raise_error(Puppet::Forge::Errors::CommunicationError,
                       %r{Unable to connect to the server at http://fake.com. Detail: Request to http://fake.com/the_path failed after .* seconds: getaddrinfo: Name or service not known.})
    end

    it "sets the user agent for the request" do
      stub_request(:get, uri).with do |request|
        expect(request.headers['User-Agent']).to match(/#{agent} #{Regexp.escape(Puppet[:http_user_agent])}/)
      end

      repository.make_http_request("/the_path")
    end

    it "does not set Authorization header by default" do
      allow(Puppet.features).to receive(:pe_license?).and_return(false)
      Puppet[:forge_authorization] = nil

      stub_request(:get, uri).with do |request|
        expect(request.headers).to_not include('Authorization')
      end

      repository.make_http_request("/the_path")
    end

    it "sets Authorization header from config" do
      token = 'bearer some token'
      Puppet[:forge_authorization] = token

      stub_request(:get, uri).with(headers: {'Authorization' => token})

      repository.make_http_request("/the_path")
    end

    it "sets Authorization header from PE license" do
      allow(Puppet.features).to receive(:pe_license?).and_return(true)
      stub_const("PELicense", double(load_license_key: double(authorization_token: "opensesame")))

      stub_request(:get, uri).with(headers: {'Authorization' => "opensesame"})

      repository.make_http_request("/the_path")
    end

    it "sets basic authentication if there isn't forge authorization or PE license" do
      stub_request(:get, uri).with(basic_auth: ['user1', 'password'])

      repository = Puppet::Forge::Repository.new('http://user1:password@fake.com', agent)
      repository.make_http_request("/the_path")
    end

    it "omits basic authentication if there is a forge authorization" do
      token = 'bearer some token'
      Puppet[:forge_authorization] = token
      stub_request(:get, uri).with(headers: {'Authorization' => token})

      repository = Puppet::Forge::Repository.new('http://user1:password@fake.com', agent)
      repository.make_http_request("/the_path")
    end

    it "encodes the URI path" do
      stub_request(:get, "http://fake.com/h%C3%A9llo%20world%20!!%20%C3%A7%20%C3%A0")

      repository.make_http_request("/héllo world !! ç à")
    end

    it "connects via proxy" do
      Puppet[:http_proxy_host] = 'proxy'
      Puppet[:http_proxy_port] = 1234

      stub_request(:get, uri)
      expect(Net::HTTP).to receive(:new).with(anything, anything, 'proxy', 1234, nil, nil).and_call_original

      repository.make_http_request("/the_path")
    end

    it "connects via authenticating proxy" do
      Puppet[:http_proxy_host] = 'proxy'
      Puppet[:http_proxy_port] = 1234
      Puppet[:http_proxy_user] = 'user1'
      Puppet[:http_proxy_password] = 'password'

      stub_request(:get, uri)
      expect(Net::HTTP).to receive(:new).with(anything, anything, 'proxy', 1234, "user1", "password").and_call_original

      repository.make_http_request("/the_path")
    end
  end
end
