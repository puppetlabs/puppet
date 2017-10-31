# encoding: utf-8
require 'spec_helper'
require 'net/http'
require 'puppet/forge/repository'

describe Puppet::Forge do
  before(:all) do
    # any local http proxy will break these tests
    ENV['http_proxy'] = nil
    ENV['HTTP_PROXY'] = nil
  end

  let(:host) { 'fake.com' }
  let(:forge) { Puppet::Forge.new("http://#{host}") }
  # creates a repository like Puppet::Forge::Repository.new('http://fake.com', USER_AGENT)

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8_query_param) { "foo + A\u06FF\u16A0\u{2070E}" } # Aۿᚠ
  let (:mixed_utf8_query_param_encoded) { "foo%20%2B%20A%DB%BF%E1%9A%A0%F0%A0%9C%8E"}
  let (:empty_json) { '{ "results": [], "pagination" : { "next" : null } }' }
  let (:ok_response) { stub('response', :code => '200', :body => empty_json) }

  describe "making a" do
    before :each do
      proxy_settings_of("proxy", 1234)
    end

    context "search request" do

      it "includes any defined module_groups, ensuring to only encode them once in the URI" do
        Puppet[:module_groups] = 'base+pe'

        # ignores Puppet::Forge::Repository#read_response, provides response to search
        performs_an_http_request(ok_response) do |http|
          encoded_uri = "/v3/modules?query=#{mixed_utf8_query_param_encoded}&module_groups=base%20pe"
          http.expects(:request).with(responds_with(:path, encoded_uri))
        end

        forge.search(mixed_utf8_query_param)
      end

      it "single encodes the search term in the URI" do
        # ignores Puppet::Forge::Repository#read_response, provides response to search
        performs_an_http_request(ok_response) do |http|
          encoded_uri = "/v3/modules?query=#{mixed_utf8_query_param_encoded}"
          http.expects(:request).with(responds_with(:path, encoded_uri))
        end

        forge.search(mixed_utf8_query_param)
      end
    end

    context "fetch request" do

      it "includes any defined module_groups, ensuring to only encode them once in the URI" do
        Puppet[:module_groups] = 'base+pe'
        module_name = 'puppetlabs-acl'

        # ignores Puppet::Forge::Repository#read_response, provides response to fetch
        performs_an_http_request(ok_response) do |http|
          encoded_uri = "/v3/releases?module=#{module_name}&sort_by=version&module_groups=base%20pe"
          http.expects(:request).with(responds_with(:path, encoded_uri))
        end

        forge.fetch(module_name)
      end

      it "single encodes the module name term in the URI" do
        module_name = "puppetlabs-#{mixed_utf8_query_param}"

        # ignores Puppet::Forge::Repository#read_response, provides response to fetch
        performs_an_http_request(ok_response) do |http|
          encoded_uri = "/v3/releases?module=puppetlabs-#{mixed_utf8_query_param_encoded}&sort_by=version"
          http.expects(:request).with(responds_with(:path, encoded_uri))
        end

        forge.fetch(module_name)
      end
    end

    def performs_an_http_request(result = nil, &block)
      proxy_args = ["proxy", 1234, nil, nil]
      mock_proxy(80, proxy_args, result, &block)
    end
  end

  def proxy_settings_of(host, port)
    Puppet[:http_proxy_host] = host
    Puppet[:http_proxy_port] = port
  end

  def mock_proxy(port, proxy_args, result, &block)
    http = mock("http client")
    proxy = mock("http proxy")
    proxy_class = mock("http proxy class")

    Net::HTTP.expects(:Proxy).with(*proxy_args).returns(proxy_class)
    proxy_class.expects(:new).with(host, port).returns(proxy)

    proxy.expects(:open_timeout=)
    proxy.expects(:read_timeout=)

    proxy.expects(:start).yields(http).returns(result)
    yield http

    proxy
  end
end
