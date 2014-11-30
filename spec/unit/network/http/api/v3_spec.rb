#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/http'
require 'puppet/network/http/api/v3'
require 'puppet/indirector_testing'

describe Puppet::Network::HTTP::API::V3 do
  let(:not_found_code) { Puppet::Network::HTTP::Error::HTTPNotFoundError::CODE }
  let(:not_acceptable_code) { Puppet::Network::HTTP::Error::HTTPNotAcceptableError::CODE }
  let(:not_authorized_code) { Puppet::Network::HTTP::Error::HTTPNotAuthorizedError::CODE }

  let(:indirection) { Puppet::IndirectorTesting.indirection }
  let(:handler) { Puppet::Network::HTTP::API::V3.new }
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }
  let(:params) { { :environment => "production" } }

  def a_request_that_heads(data, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/pson", },
      :method => "HEAD",
      :path => "/#{indirection.name}/#{data.value}",
      :params => params,
    })
  end

  def a_request_that_submits(data, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => request[:content_type_header] || "text/pson", },
      :method => "PUT",
      :path => "/#{indirection.name}/#{data.value}",
      :params => params,
      :body => request[:body].nil? ? data.render("pson") : request[:body]
    })
  end

  def a_request_that_destroys(data, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/pson", },
      :method => "DELETE",
      :path => "/#{indirection.name}/#{data.value}",
      :params => params,
      :body => ''
    })
  end

  def a_request_that_finds(data, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/pson", },
      :method => "GET",
      :path => "/#{indirection.name}/#{data.value}",
      :params => params,
      :body => ''
    })
  end

  def a_request_that_searches(key, request = {})
    Puppet::Network::HTTP::Request.from_hash({
      :headers => {
        'accept' => request[:accept_header],
        'content-type' => "text/pson", },
      :method => "GET",
      :path => "/#{indirection.name}s/#{key}",
      :params => params,
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
    let(:environment) { Puppet::Node::Environment.create(:env, []) }
    let(:env_loaders) { Puppet::Environments::Static.new(environment) }
    let(:params) { { :environment => "env" } }

    before do
      handler.stubs(:handler).returns "foo"
    end

    around do |example|
      Puppet.override(:environments => env_loaders) do
        example.run
      end
    end

    it "should get the environment from a query parameter" do
      handler.uri2indirection("GET", "/foo/bar", params)[3][:environment].to_s.should == "env"
    end

    it "should fail if the environment is not alphanumeric" do
      lambda { handler.uri2indirection("GET", "/foo/bar", {:environment => "env ness"}) }.should raise_error(ArgumentError)
    end

    it "should not pass a buck_path parameter through (See Bugs #13553, #13518, #13511)" do
      handler.uri2indirection("GET", "/foo/bar", { :environment => "env",
                                                   :bucket_path => "/malicious/path" })[3].should_not include({ :bucket_path => "/malicious/path" })
    end

    it "should pass allowed parameters through" do
      handler.uri2indirection("GET", "/foo/bar", { :environment => "env",
                                                   :allowed_param => "value" })[3].should include({ :allowed_param => "value" })
    end

    it "should return the environment as a Puppet::Node::Environment" do
      handler.uri2indirection("GET", "/foo/bar", params)[3][:environment].should be_a(Puppet::Node::Environment)
    end

    it "should use the first field of the URI as the indirection name" do
      handler.uri2indirection("GET", "/foo/bar", params)[0].should == "foo"
    end

    it "should fail if the indirection name is not alphanumeric" do
      lambda { handler.uri2indirection("GET", "/foo ness/bar", params) }.should raise_error(ArgumentError)
    end

    it "should use the remainder of the URI as the indirection key" do
      handler.uri2indirection("GET", "/foo/bar", params)[2].should == "bar"
    end

    it "should support the indirection key being a /-separated file path" do
      handler.uri2indirection("GET", "/foo/bee/baz/bomb", params)[2].should == "bee/baz/bomb"
    end

    it "should fail if no indirection key is specified" do
      lambda { handler.uri2indirection("GET", "/foo", params) }.should raise_error(ArgumentError)
    end

    it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is singular" do
      handler.uri2indirection("GET", "/foo/bar", params)[1].should == :find
    end

    it "should choose 'find' as the indirection method if the http method is a POST and the indirection name is singular" do
      handler.uri2indirection("POST", "/foo/bar", params)[1].should == :find
    end

    it "should choose 'head' as the indirection method if the http method is a HEAD and the indirection name is singular" do
      handler.uri2indirection("HEAD", "/foo/bar", params)[1].should == :head
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is plural" do
      handler.uri2indirection("GET", "/foos/bar", params)[1].should == :search
    end

    it "should change indirection name to 'status' if the http method is a GET and the indirection name is statuses" do
      handler.uri2indirection("GET", "/statuses/bar", params)[0].should == "status"
    end

    it "should change indirection name to 'node' if the http method is a GET and the indirection name is nodes" do
      handler.uri2indirection("GET", "/nodes/bar", params)[0].should == "node"
    end

    it "should choose 'delete' as the indirection method if the http method is a DELETE and the indirection name is singular" do
      handler.uri2indirection("DELETE", "/foo/bar", params)[1].should == :destroy
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is singular" do
      handler.uri2indirection("PUT", "/foo/bar", params)[1].should == :save
    end

    it "should fail if an indirection method cannot be picked" do
      lambda { handler.uri2indirection("UPDATE", "/node/bar", params) }.should raise_error(ArgumentError)
    end

    it "should URI unescape the indirection key" do
      escaped = URI.escape("foo bar")
      indirection, method, key, final_params = handler.uri2indirection("GET", "/node/#{escaped}", params)
      key.should == "foo bar"
    end
  end

  describe "when converting a request into a URI" do
    let(:environment) { Puppet::Node::Environment.create(:myenv, []) }
    let(:request) { Puppet::Indirector::Request.new(:foo, :find, "with spaces", nil, :foo => :bar, :environment => environment) }

    before do
      handler.stubs(:handler).returns "foo"
    end

    it "should include the environment in the query string of the URI" do
      handler.class.request_to_uri(request).should == "/foo/with%20spaces?environment=myenv&foo=bar"
    end

    it "should pluralize the indirection name if the method is 'search'" do
      request.stubs(:method).returns :search
      handler.class.request_to_uri(request).split("/")[1].should == "foos"
    end

    it "should add the query string to the URI" do
      request.expects(:query_string).returns "query"
      handler.class.request_to_uri(request).should =~ /\&query$/
    end
  end

  describe "when converting a request into a URI with body" do
    let(:environment) { Puppet::Node::Environment.create(:myenv, []) }
    let(:request) { Puppet::Indirector::Request.new(:foo, :find, "with spaces", nil, :foo => :bar, :environment => environment) }

    it "should use the indirection as the first field of the URI" do
      handler.class.request_to_uri_and_body(request).first.split("/")[1].should == "foo"
    end

    it "should use the escaped key as the remainder of the URI" do
      escaped = URI.escape("with spaces")
      handler.class.request_to_uri_and_body(request).first.split("/")[2].sub(/\?.+/, '').should == escaped
    end

    it "should return the URI and body separately" do
      handler.class.request_to_uri_and_body(request).should == ["/foo/with%20spaces", "environment=myenv&foo=bar"]
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
      request = a_request_that_finds(data, :accept_header => "unknown, pson")

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
      request = a_request_that_finds(data, :accept_header => "text/pson")
      indirection.expects(:find).returns(data_string)

      handler.call(request, response)

      expect(response.body).to eq(data_string)
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "should return a not_found_code when no model instance can be found" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_finds(data, :accept_header => "unknown, text/pson")

      handler.call(request, response)
      expect(response.code).to eq(not_found_code)
    end
  end

  describe "when searching for model instances" do
    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_searches("my", :accept_header => "unknown, text/pson")

      handler.call(request, response)

      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
      expect(response.body).to eq(Puppet::IndirectorTesting.render_multiple(:pson, [data]))
    end

    it "should return [] when searching returns an empty array" do
      request = a_request_that_searches("nothing", :accept_header => "unknown, text/pson")

      handler.call(request, response)

      expect(response.body).to eq("[]")
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "should return a not_found_code when searching returns nil" do
      request = a_request_that_searches("nothing", :accept_header => "unknown, text/pson")
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

    it "responds with pson when no Accept header is given" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data, :accept_header => nil)

      handler.call(request, response)

      expect(response.body).to eq(data.render(:pson))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data, :accept_header => "unknown, text/pson")

      handler.call(request, response)

      expect(response.body).to eq(data.render(:pson))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "raises an error and does not destroy when no accepted formats are known" do
      data = Puppet::IndirectorTesting.new("my data")
      indirection.save(data, "my data")
      request = a_request_that_destroys(data, :accept_header => "unknown, also/unknown")

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

      # PUP-3272 this test fails when yaml is removed and pson is used. Instead of returning an
      # empty string, the a string '""' is returned - Don't know what the expecation is, if this is
      # corrent or not.
      # (helindbe)
      #
      Puppet::IndirectorTesting.indirection.find("test").name.should == ''
    end

    it "saves the data sent in the request" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data)

      handler.call(request, response)

      saved = Puppet::IndirectorTesting.indirection.find("my data")
      expect(saved.name).to eq(data.name)
    end

    it "responds with pson when no Accept header is given" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :accept_header => nil)

      handler.call(request, response)

      expect(response.body).to eq(data.render(:pson))
      expect(response.type).to eq(Puppet::Network::FormatHandler.format(:pson))
    end

    it "uses the first supported format for the response" do
      data = Puppet::IndirectorTesting.new("my data")
      request = a_request_that_submits(data, :accept_header => "unknown, text/pson")

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
