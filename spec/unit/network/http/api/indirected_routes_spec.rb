require 'spec_helper'

require 'puppet/network/http'
require 'puppet/network/http/api/indirected_routes'
require 'puppet/indirector_testing'
require 'puppet_spec/network'

RSpec::Matchers.define_negated_matcher :excluding, :include

describe Puppet::Network::HTTP::API::IndirectedRoutes do
  include PuppetSpec::Network

  let(:indirection) { Puppet::IndirectorTesting.indirection }
  let(:handler) { Puppet::Network::HTTP::API::IndirectedRoutes.new }
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

  before do
    Puppet::IndirectorTesting.indirection.terminus_class = :memory
    Puppet::IndirectorTesting.indirection.terminus.clear
    allow(handler).to receive(:warn_if_near_expiration)
  end

  describe "when converting a URI into a request" do
    let(:environment) { Puppet::Node::Environment.create(:env, []) }
    let(:env_loaders) { Puppet::Environments::Static.new(environment) }
    let(:params) { { :environment => "env" } }

    before do
      allow(handler).to receive(:handler).and_return("foo")
    end

    around do |example|
      Puppet.override(:environments => env_loaders) do
        example.run
      end
    end

    it "should get the environment from a query parameter" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/node/bar", params)[3][:environment].to_s).to eq("env")
    end

    it "should fail if there is no environment specified" do
      expect {
        handler.uri2indirection("GET", "#{master_url_prefix}/node/bar", {})
      }.to raise_error(bad_request_error)
    end

    it "should fail if the environment is not alphanumeric" do
      expect {
        handler.uri2indirection("GET", "#{master_url_prefix}/node/bar", {:environment => "env ness"})
      }.to raise_error(bad_request_error)
    end

    it "should fail if the indirection does not match the prefix" do
      expect {
        handler.uri2indirection("GET", "#{master_url_prefix}/certificate/foo", params)
      }.to raise_error(bad_request_error)
    end

    it "should fail if the indirection does not have the correct version" do
      expect {
        handler.uri2indirection("GET", "#{Puppet::Network::HTTP::MASTER_URL_PREFIX}/v1/node/bar", params)
      }.to raise_error(bad_request_error)
    end

    it "should not pass a buck_path parameter through (See Bugs #13553, #13518, #13511)" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/node/bar",
                              { :environment => "env",
                                :bucket_path => "/malicious/path" })[3]).not_to include({ :bucket_path => "/malicious/path" })
    end

    it "should pass allowed parameters through" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/node/bar",
                              { :environment => "env",
                                :allowed_param => "value" })[3]).to include({ :allowed_param => "value" })
    end

    it "should return the environment as a Puppet::Node::Environment" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/node/bar", params)[3][:environment]).to be_a(Puppet::Node::Environment)
    end

    it "should use the first field of the URI as the indirection name" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/node/bar", params)[0].name).to eq(:node)
    end

    it "should fail if the indirection name is not alphanumeric" do
      expect {
        handler.uri2indirection("GET", "#{master_url_prefix}/foo ness/bar", params)
      }.to raise_error(bad_request_error)
    end

    it "should use the remainder of the URI as the indirection key" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/node/bar", params)[2]).to eq("bar")
    end

    it "should support the indirection key being a /-separated file path" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/node/bee/baz/bomb", params)[2]).to eq("bee/baz/bomb")
    end

    it "should fail if no indirection key is specified" do
      expect {
        handler.uri2indirection("GET", "#{master_url_prefix}/node", params)
      }.to raise_error(bad_request_error)
    end

    it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is singular" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/node/bar", params)[1]).to eq(:find)
    end

    it "should choose 'find' as the indirection method if the http method is a POST and the indirection name is singular" do
      expect(handler.uri2indirection("POST", "#{master_url_prefix}/node/bar", params)[1]).to eq(:find)
    end

    it "should choose 'head' as the indirection method if the http method is a HEAD and the indirection name is singular" do
      expect(handler.uri2indirection("HEAD", "#{master_url_prefix}/node/bar", params)[1]).to eq(:head)
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is plural" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/nodes/bar", params)[1]).to eq(:search)
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is facts" do
      expect(handler.uri2indirection("PUT", "#{master_url_prefix}/facts/puppet.node.test", params)[0].name).to eq(:facts)
    end

    it "should change indirection name to 'node' if the http method is a GET and the indirection name is nodes" do
      expect(handler.uri2indirection("GET", "#{master_url_prefix}/nodes/bar", params)[0].name).to eq(:node)
    end

    it "should choose 'delete' as the indirection method if the http method is a DELETE and the indirection name is singular" do
      expect(handler.uri2indirection("DELETE", "#{master_url_prefix}/node/bar", params)[1]).to eq(:destroy)
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is singular" do
      expect(handler.uri2indirection("PUT", "#{master_url_prefix}/node/bar", params)[1]).to eq(:save)
    end

    it "should fail if an indirection method cannot be picked" do
      expect {
        handler.uri2indirection("UPDATE", "#{master_url_prefix}/node/bar", params)
      }.to raise_error(method_not_allowed_error)
    end

    it "should not URI unescape the indirection key" do
      escaped = Puppet::Util.uri_encode("foo bar")
      _, _, key, _ = handler.uri2indirection("GET", "#{master_url_prefix}/node/#{escaped}", params)
      expect(key).to eq(escaped)
    end
  end

  describe "when processing a request" do
    it "should raise not_found_error if the indirection does not support remote requests" do
      request = a_request_that_heads(Puppet::IndirectorTesting.new("my data"))

      expect(indirection).to receive(:allow_remote_requests?).and_return(false)

      expect {
        handler.call(request, response)
      }.to raise_error(not_found_error)
    end

    it "should raise not_found_error if the environment does not exist" do
      Puppet.override(:environments => Puppet::Environments::Static.new()) do
        request = a_request_that_heads(Puppet::IndirectorTesting.new("my data"))

        expect {
          handler.call(request, response)
        }.to raise_error(not_found_error)
      end
    end
  end

  describe "when finding a model instance" do
    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_finds(data, :accept_header => "unknown, application/json")

      handler.call(request, response)

      expect(response.body).to eq(data.render(:json))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:json))
    end

    it "falls back to the next supported format" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_finds(data, :accept_header => "application/json, text/pson")
      allow(data).to receive(:to_json).and_raise(Puppet::Network::FormatHandler::FormatError, 'Could not render to Puppet::Network::Format[json]: source sequence is illegal/malformed utf-8')

      handler.call(request, response)

      expect(response.body).to eq(data.render(:pson))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "should pass the result through without rendering it if the result is a string" do
      data = Puppet::IndirectorTesting.new("my data")
      data_string = "my data string"
      request = a_request_that_finds(data, :accept_header => "application/json")
      expect(indirection).to receive(:find).and_return(data_string)

      handler.call(request, response)

      expect(response.body).to eq(data_string)
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:json))
    end

    it "should raise not_found_error when no model instance can be found" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_finds(data, :accept_header => "unknown, application/json")

      expect {
        handler.call(request, response)
      }.to raise_error(not_found_error)
    end
  end

  describe "when searching for model instances" do
    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_searches(Puppet::IndirectorTesting.new("my"), :accept_header => "unknown, application/json")

      handler.call(request, response)

      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:json))
      expect(response.body).to eq(Puppet::IndirectorTesting.render_multiple(:json, [data]))
    end

    it "falls back to the next supported format" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_searches(Puppet::IndirectorTesting.new("my"), :accept_header => "application/json, text/pson")
      allow(data).to receive(:to_json).and_raise(Puppet::Network::FormatHandler::FormatError, 'Could not render to Puppet::Network::Format[json]: source sequence is illegal/malformed utf-8')

      handler.call(request, response)

      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
      expect(response.body).to eq(Puppet::IndirectorTesting.render_multiple(:pson, [data]))
    end

    it "raises 406 not acceptable if no formats are accceptable" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_searches(Puppet::IndirectorTesting.new("my"), :accept_header => "application/json, text/pson")
      allow(data).to receive(:to_json).and_raise(Puppet::Network::FormatHandler::FormatError, 'Could not render to Puppet::Network::Format[json]: source sequence is illegal/malformed utf-8')
      allow(data).to receive(:to_pson).and_raise(Puppet::Network::FormatHandler::FormatError, 'Could not render to Puppet::Network::Format[pson]: source sequence is illegal/malformed utf-8')

      expect {
        handler.call(request, response)
      }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotAcceptableError,
                       %r{No supported formats are acceptable \(Accept: application/json, text/pson\)})
    end

    it "should return [] when searching returns an empty array" do
      request = a_request_that_searches(Puppet::IndirectorTesting.new("nothing"), :accept_header => "unknown, application/json")

      handler.call(request, response)

      expect(response.body).to eq("[]")
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:json))
    end

    it "should raise not_found_error when searching returns nil" do
      request = a_request_that_searches(Puppet::IndirectorTesting.new("nothing"), :accept_header => "unknown, application/json")
      expect(indirection).to receive(:search).and_return(nil)

      expect {
        handler.call(request, response)
      }.to raise_error(not_found_error)
    end
  end

  describe "when destroying a model instance" do
    it "destroys the data indicated in the request" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data)

      handler.call(request, response)

      expect(Puppet::IndirectorTesting.indirection.find("my data")).to be_nil
    end

    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data, :accept_header => "unknown, application/json")

      handler.call(request, response)

      expect(response.body).to eq(data.render(:json))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:json))
    end

    it "raises an error and does not destroy when no accepted formats are known" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data, :accept_header => "unknown, also/unknown")

      expect {
        handler.call(request, response)
      }.to raise_error(not_acceptable_error)

      expect(Puppet::IndirectorTesting.indirection.find("my data")).not_to be_nil
    end
  end

  describe "when saving a model instance" do
    it "allows an empty body when the format supports it" do
      class Puppet::IndirectorTesting::Nonvalidatingmemory < Puppet::IndirectorTesting::Memory
        def validate_key(_)
          # nothing
        end
      end

      indirection.terminus_class = :nonvalidatingmemory

      data = Puppet::IndirectorTesting.new("test")
      request = a_request_that_submits(data,
                                       :content_type_header => "application/octet-stream",
                                       :body => '')

      handler.call(request, response)

      saved = Puppet::IndirectorTesting.indirection.find("test")
      expect(saved.name).to eq('')
    end

    it "saves the data sent in the request" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data)

      handler.call(request, response)

      saved = Puppet::IndirectorTesting.indirection.find("my data")
      expect(saved.name).to eq(data.name)
    end

    it "responds with bad request when failing to parse the body" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :content_type_header => 'application/json', :body => "this is invalid json content")

      expect {
        handler.call(request, response)
      }.to raise_error(bad_request_error, /The request body is invalid: Could not intern from json/)
    end

    it "responds with unsupported media type error when submitted content is known, but not supported by the model" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :content_type_header => 's')
      expect(data).to_not be_support_format('s')

      expect {
        handler.call(request, response)
      }.to raise_error(unsupported_media_type_error, /Client sent a mime-type \(s\) that doesn't correspond to a format we support/)
    end

    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :accept_header => "unknown, application/json")

      handler.call(request, response)

      expect(response.body).to eq(data.render(:json))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:json))
    end

    it "raises an error and does not save when no accepted formats are known" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :accept_header => "unknown, also/unknown")

      expect {
        handler.call(request, response)
      }.to raise_error(not_acceptable_error)

      expect(Puppet::IndirectorTesting.indirection.find("my data")).to be_nil
    end
  end

  describe "when performing head operation" do
    it "should not generate a response when a model head call succeeds" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_heads(data)

      handler.call(request, response)

      expect(response.code).to eq(nil)
    end

    it "should raise not_found_error when the model head call returns false" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_heads(data)

      expect {
        handler.call(request, response)
      }.to raise_error(not_found_error)
    end
  end
end
