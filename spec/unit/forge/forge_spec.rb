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

  let(:host) { 'http://fake.com' }
  let(:forge) { Puppet::Forge.new(host) }

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let (:mixed_utf8_query_param) { "foo + A\u06FF\u16A0\u{2070E}" } # Aۿᚠ
  let (:mixed_utf8_query_param_encoded) { "foo%20%2B%20A%DB%BF%E1%9A%A0%F0%A0%9C%8E"}
  let (:empty_json) { '{ "results": [], "pagination" : { "next" : null } }' }

  describe "making a" do
    before :each do
      Puppet[:http_proxy_host] = "proxy"
      Puppet[:http_proxy_port] = 1234
    end

    context "search request" do
      it "includes any defined module_groups, ensuring to only encode them once in the URI" do
        Puppet[:module_groups] = 'base+pe'
        encoded_uri = "#{host}/v3/modules?query=#{mixed_utf8_query_param_encoded}&module_groups=base%20pe"
        stub_request(:get, encoded_uri).to_return(status: 200, body: empty_json)

        forge.search(mixed_utf8_query_param)
      end

      it "single encodes the search term in the URI" do
        encoded_uri = "#{host}/v3/modules?query=#{mixed_utf8_query_param_encoded}"
        stub_request(:get, encoded_uri).to_return(status: 200, body: empty_json)

        forge.search(mixed_utf8_query_param)
      end
    end

    context "fetch request" do
      it "includes any defined module_groups, ensuring to only encode them once in the URI" do
        Puppet[:module_groups] = 'base+pe'
        module_name = 'puppetlabs-acl'
        exclusions = "readme%2Cchangelog%2Clicense%2Curi%2Cmodule%2Ctags%2Csupported%2Cfile_size%2Cdownloads%2Ccreated_at%2Cupdated_at%2Cdeleted_at"
        encoded_uri = "#{host}/v3/releases?module=#{module_name}&sort_by=version&exclude_fields=#{exclusions}&module_groups=base%20pe"
        stub_request(:get, encoded_uri).to_return(status: 200, body: empty_json)

        forge.fetch(module_name)
      end

      it "single encodes the module name term in the URI" do
        module_name = "puppetlabs-#{mixed_utf8_query_param}"
        exclusions = "readme%2Cchangelog%2Clicense%2Curi%2Cmodule%2Ctags%2Csupported%2Cfile_size%2Cdownloads%2Ccreated_at%2Cupdated_at%2Cdeleted_at"
        encoded_uri = "#{host}/v3/releases?module=puppetlabs-#{mixed_utf8_query_param_encoded}&sort_by=version&exclude_fields=#{exclusions}"
        stub_request(:get, encoded_uri).to_return(status: 200, body: empty_json)

        forge.fetch(module_name)
      end
    end
  end
end
