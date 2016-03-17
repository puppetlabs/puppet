#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/http'
require 'puppet/network/http/api/v1'
require 'puppet/indirector_testing'

describe Puppet::Network::HTTP::API::V1 do
  let(:not_found_code) { Puppet::Network::HTTP::Error::HTTPNotFoundError::CODE }
  let(:not_acceptable_code) { Puppet::Network::HTTP::Error::HTTPNotAcceptableError::CODE }
  let(:not_authorized_code) { Puppet::Network::HTTP::Error::HTTPNotAuthorizedError::CODE }

  let(:indirection) { Puppet::IndirectorTesting.indirection }
  let(:handler) { Puppet::Network::HTTP::API::V1.new }
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

  def a_request_that_heads(data, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/yaml", },
      :method => "HEAD",
      :path => "/production/#{indirection.name}/#{data.value}",
      :params => {},
    })
  end

  def a_request_that_submits(data, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => request[:content_type_header] || "text/yaml", },
      :method => "PUT",
      :path => "/production/#{indirection.name}/#{data.value}",
      :params => {},
      :body => request[:body] || data.render("text/yaml")
    })
  end

  def a_request_that_destroys(data, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/yaml", },
      :method => "DELETE",
      :path => "/production/#{indirection.name}/#{data.value}",
      :params => {},
      :body => ''
    })
  end

  def a_request_that_finds(data, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/yaml", },
      :method => "GET",
      :path => "/production/#{indirection.name}/#{data.value}",
      :params => {},
      :body => ''
    })
  end

  def a_request_that_searches(key, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/yaml", },
      :method => "GET",
      :path => "/production/#{indirection.name}s/#{key}",
      :params => {},
      :body => ''
    })
  end


  before do
    Puppet::IndirectorTesting.indirection.terminus_class = :memory
    Puppet::IndirectorTesting.indirection.terminus.clear
    handler.stubs(:check_authorization)
    handler.stubs(:warn_if_near_expiration)
  end

  describe "when converting a URI into a request" do
    before do
      handler.stubs(:handler).returns "foo"
    end

    it "should require the http method, the URI, and the query parameters" do
      # Not a terribly useful test, but an important statement for the spec
      lambda { handler.uri2indirection("/foo") }.should raise_error(ArgumentError)
    end

    it "should use the first field of the URI as the environment" do
      handler.uri2indirection("GET", "/env/foo/bar", {})[3][:environment].to_s.should == "env"
    end

    it "should fail if the environment is not alphanumeric" do
      lambda { handler.uri2indirection("GET", "/env ness/foo/bar", {}) }.should raise_error(ArgumentError)
    end

    it "should use the environment from the URI even if one is specified in the parameters" do
      handler.uri2indirection("GET", "/env/foo/bar", {:environment => "otherenv"})[3][:environment].to_s.should == "env"
    end

    it "should not pass a buck_path parameter through (See Bugs #13553, #13518, #13511)" do
      handler.uri2indirection("GET", "/env/foo/bar", { :bucket_path => "/malicious/path" })[3].should_not include({ :bucket_path => "/malicious/path" })
    end

    it "should pass allowed parameters through" do
      handler.uri2indirection("GET", "/env/foo/bar", { :allowed_param => "value" })[3].should include({ :allowed_param => "value" })
    end

    it "should return the environment as a Puppet::Node::Environment" do
      handler.uri2indirection("GET", "/env/foo/bar", {})[3][:environment].should be_a Puppet::Node::Environment
    end

    it "should not pass a buck_path parameter through (See Bugs #13553, #13518, #13511)" do
      handler.uri2indirection("GET", "/env/foo/bar", { :bucket_path => "/malicious/path" })[3].should_not include({ :bucket_path => "/malicious/path" })
    end

    it "should pass allowed parameters through" do
      handler.uri2indirection("GET", "/env/foo/bar", { :allowed_param => "value" })[3].should include({ :allowed_param => "value" })
    end

    it "should use the second field of the URI as the indirection name" do
      handler.uri2indirection("GET", "/env/foo/bar", {})[0].should == "foo"
    end

    it "should fail if the indirection name is not alphanumeric" do
      lambda { handler.uri2indirection("GET", "/env/foo ness/bar", {}) }.should raise_error(ArgumentError)
    end

    it "should use the remainder of the URI as the indirection key" do
      handler.uri2indirection("GET", "/env/foo/bar", {})[2].should == "bar"
    end

    it "should support the indirection key being a /-separated file path" do
      handler.uri2indirection("GET", "/env/foo/bee/baz/bomb", {})[2].should == "bee/baz/bomb"
    end

    it "should fail if no indirection key is specified" do
      lambda { handler.uri2indirection("GET", "/env/foo/", {}) }.should raise_error(ArgumentError)
      lambda { handler.uri2indirection("GET", "/env/foo", {}) }.should raise_error(ArgumentError)
    end

    it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is singular" do
      handler.uri2indirection("GET", "/env/foo/bar", {})[1].should == :find
    end

    it "should choose 'find' as the indirection method if the http method is a POST and the indirection name is singular" do
      handler.uri2indirection("POST", "/env/foo/bar", {})[1].should == :find
    end

    it "should choose 'head' as the indirection method if the http method is a HEAD and the indirection name is singular" do
      handler.uri2indirection("HEAD", "/env/foo/bar", {})[1].should == :head
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is plural" do
      handler.uri2indirection("GET", "/env/foos/bar", {})[1].should == :search
    end

    it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is facts" do
      handler.uri2indirection("GET", "/env/facts/bar", {})[1].should == :find
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is facts" do
      handler.uri2indirection("PUT", "/env/facts/bar", {})[1].should == :save
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is inventory" do
      handler.uri2indirection("GET", "/env/inventory/search", {})[1].should == :search
    end

    it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is facts" do
      handler.uri2indirection("GET", "/env/facts/bar", {})[1].should == :find
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is facts" do
      handler.uri2indirection("PUT", "/env/facts/bar", {})[1].should == :save
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is inventory" do
      handler.uri2indirection("GET", "/env/inventory/search", {})[1].should == :search
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is facts_search" do
      handler.uri2indirection("GET", "/env/facts_search/bar", {})[1].should == :search
    end

    it "should change indirection name to 'facts' if the http method is a GET and the indirection name is facts_search" do
      handler.uri2indirection("GET", "/env/facts_search/bar", {})[0].should == 'facts'
    end

    it "should not change indirection name from 'facts' if the http method is a GET and the indirection name is facts" do
      handler.uri2indirection("GET", "/env/facts/bar", {})[0].should == 'facts'
    end

    it "should change indirection name to 'status' if the http method is a GET and the indirection name is statuses" do
      handler.uri2indirection("GET", "/env/statuses/bar", {})[0].should == 'status'
    end

    it "should change indirection name to 'probe' if the http method is a GET and the indirection name is probes" do
      handler.uri2indirection("GET", "/env/probes/bar", {})[0].should == 'probe'
    end

    it "should choose 'delete' as the indirection method if the http method is a DELETE and the indirection name is singular" do
      handler.uri2indirection("DELETE", "/env/foo/bar", {})[1].should == :destroy
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is singular" do
      handler.uri2indirection("PUT", "/env/foo/bar", {})[1].should == :save
    end

    it "should fail if an indirection method cannot be picked" do
      lambda { handler.uri2indirection("UPDATE", "/env/foo/bar", {}) }.should raise_error(ArgumentError)
    end

    it "should URI unescape the indirection key" do
      escaped = URI.escape("foo bar")
      indirection_name, method, key, params = handler.uri2indirection("GET", "/env/foo/#{escaped}", {})
      key.should == "foo bar"
    end
  end

  describe "when converting a request into a URI" do
    let(:request) { Puppet::Indirector::Request.new(:foo, :find, "with spaces", nil, :foo => :bar, :environment => "myenv") }

    it "should use the environment as the first field of the URI" do
      handler.class.indirection2uri(request).split("/")[1].should == "myenv"
    end

    it "should use the indirection as the second field of the URI" do
      handler.class.indirection2uri(request).split("/")[2].should == "foo"
    end

    it "should pluralize the indirection name if the method is 'search'" do
      request.stubs(:method).returns :search
      handler.class.indirection2uri(request).split("/")[2].should == "foos"
    end

    it "should use the escaped key as the remainder of the URI" do
      escaped = URI.escape("with spaces")
      handler.class.indirection2uri(request).split("/")[3].sub(/\?.+/, '').should == escaped
    end

    it "should add the query string to the URI" do
      request.expects(:query_string).returns "?query"
      handler.class.indirection2uri(request).should =~ /\?query$/
    end
  end

  describe "when converting a request into a URI with body" do
    let(:request) { Puppet::Indirector::Request.new(:foo, :find, "with spaces", nil, :foo => :bar, :environment => "myenv") }

    it "should use the environment as the first field of the URI" do
      handler.class.request_to_uri_and_body(request).first.split("/")[1].should == "myenv"
    end

    it "should use the indirection as the second field of the URI" do
      handler.class.request_to_uri_and_body(request).first.split("/")[2].should == "foo"
    end

    it "should use the escaped key as the remainder of the URI" do
      escaped = URI.escape("with spaces")
      handler.class.request_to_uri_and_body(request).first.split("/")[3].sub(/\?.+/, '').should == escaped
    end

    it "should return the URI and body separately" do
      handler.class.request_to_uri_and_body(request).should == ["/myenv/foo/with%20spaces", "foo=bar"]
    end
  end

  describe "when processing a request" do
    it "should return not_authorized_code if the request is not authorized" do
      request = a_request_that_heads(Puppet::IndirectorTesting.new("my data"))

      handler.expects(:check_authorization).raises(Puppet::Network::AuthorizationError.new("forbidden"))

      handler.call(request, response)

      expect(response.code).to eq(not_authorized_code)
    end

    it "should return 'not found' if the indirection does not support remote requests" do
      request = a_request_that_heads(Puppet::IndirectorTesting.new("my data"))

      indirection.expects(:allow_remote_requests?).returns(false)

      handler.call(request, response)

      expect(response.code).to eq(not_found_code)
    end

    it "should return 'not found' if the environment does not exist" do
      Puppet.override(:environments => Puppet::Environments::Static.new()) do
        request = a_request_that_heads(Puppet::IndirectorTesting.new("my data"))

        handler.call(request, response)

        expect(response.code).to eq(not_found_code)
      end
    end

    it "should serialize a controller exception when an exception is thrown while finding the model instance" do
      request = a_request_that_finds(Puppet::IndirectorTesting.new("key"))
      handler.expects(:do_find).raises(ArgumentError, "The exception")

      handler.call(request, response)

      expect(response.code).to eq(400)
      expect(response.body).to eq("The exception")
      expect(response.type).to eq("text/plain")
    end
  end

  describe "when finding a model instance" do
    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_finds(data, :accept_header => "unknown, pson, yaml")

      handler.call(request, response)

      expect(response.body).to eq(data.render(:pson))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "responds with a not_acceptable_code error when no accept header is provided" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_finds(data, :accept_header => nil)

      handler.call(request, response)

      expect(response.code).to eq(not_acceptable_code)
    end

    it "raises an error when no accepted formats are known" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_finds(data, :accept_header => "unknown, also/unknown")

      handler.call(request, response)

      expect(response.code).to eq(not_acceptable_code)
    end

    it "should pass the result through without rendering it if the result is a string" do
      data = Puppet::IndirectorTesting.new("my data")
      data_string = "my data string"
      request = a_request_that_finds(data, :accept_header => "pson")
      indirection.expects(:find).returns(data_string)

      handler.call(request, response)

      expect(response.body).to eq(data_string)
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "should return a not_found_code when no model instance can be found" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_finds(data, :accept_header => "unknown, pson, yaml")

      handler.call(request, response)
      expect(response.code).to eq(not_found_code)
    end
  end

  describe "when searching for model instances" do
    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_searches("my", :accept_header => "unknown, pson, yaml")

      handler.call(request, response)

      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
      expect(response.body).to eq(Puppet::IndirectorTesting.render_multiple(:pson, [data]))
    end

    it "should return [] when searching returns an empty array" do
      request = a_request_that_searches("nothing", :accept_header => "unknown, pson, yaml")

      handler.call(request, response)

      expect(response.body).to eq("[]")
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "should return a not_found_code when searching returns nil" do
      request = a_request_that_searches("nothing", :accept_header => "unknown, pson, yaml")
      indirection.expects(:search).returns(nil)

      handler.call(request, response)

      expect(response.code).to eq(not_found_code)
    end
  end

  describe "when destroying a model instance" do
    it "destroys the data indicated in the request" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data)

      handler.call(request, response)

      Puppet::IndirectorTesting.indirection.find("my data").should be_nil
    end

    it "responds with yaml when no Accept header is given" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data, :accept_header => nil)

      handler.call(request, response)

      expect(response.body).to eq(data.render(:yaml))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:yaml))
    end

    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data, :accept_header => "unknown, pson, yaml")

      handler.call(request, response)

      expect(response.body).to eq(data.render(:pson))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "raises an error and does not destroy when no accepted formats are known" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_submits(data, :accept_header => "unknown, also/unknown")

      handler.call(request, response)

      expect(response.code).to eq(not_acceptable_code)
      Puppet::IndirectorTesting.indirection.find("my data").should_not be_nil
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
                                       :content_type_header => "application/x-raw",
                                       :body => '')

      handler.call(request, response)

      Puppet::IndirectorTesting.indirection.find("test").name.should == ''
    end

    it "saves the data sent in the request" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data)

      handler.call(request, response)

      saved = Puppet::IndirectorTesting.indirection.find("my data")
      expect(saved.name).to eq(data.name)
    end

    it "responds with yaml when no Accept header is given" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :accept_header => nil)

      handler.call(request, response)

      expect(response.body).to eq(data.render(:yaml))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:yaml))
    end

    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :accept_header => "unknown, pson, yaml")

      handler.call(request, response)

      expect(response.body).to eq(data.render(:pson))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "raises an error and does not save when no accepted formats are known" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :accept_header => "unknown, also/unknown")

      handler.call(request, response)

      expect(Puppet::IndirectorTesting.indirection.find("my data")).to be_nil
      expect(response.code).to eq(not_acceptable_code)
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

    it "should return a not_found_code when the model head call returns false" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_heads(data)

      handler.call(request, response)

      expect(response.code).to eq(not_found_code)
      expect(response.type).to eq("text/plain")
      expect(response.body).to eq("Not Found: Could not find indirector_testing my data")
    end
  end
end
