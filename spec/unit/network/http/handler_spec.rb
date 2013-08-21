#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http'
require 'puppet/network/http/handler'
require 'puppet/network/authorization'
require 'puppet/network/authentication'
require 'puppet/indirector/memory'

describe Puppet::Network::HTTP::Handler do
  before :each do
    class Puppet::TestModel
      extend Puppet::Indirector
      indirects :test_model
      attr_accessor :name, :data
      def initialize(name = "name", data = '')
        @name = name
        @data = data
      end

      def self.from_pson(pson)
        new(pson["name"], pson["data"])
      end

      def to_pson
        {
          "name" => @name,
          "data" => @data
        }.to_pson
      end

      def ==(other)
        other.is_a? Puppet::TestModel and other.name == name and other.data == data
      end
    end

    # The subclass must not be all caps even though the superclass is
    class Puppet::TestModel::Memory < Puppet::Indirector::Memory
    end

    Puppet::TestModel.indirection.terminus_class = :memory
  end

  after :each do
    Puppet::TestModel.indirection.delete
    # Remove the class, unlinking it from the rest of the system.
    Puppet.send(:remove_const, :TestModel)
  end

  let(:terminus_class) { Puppet::TestModel::Memory }
  let(:terminus) { Puppet::TestModel.indirection.terminus(:memory) }
  let(:indirection) { Puppet::TestModel.indirection }
  let(:model) { Puppet::TestModel }

  def a_request
    {
      :accept_header => "pson",
      :content_type_header => "text/yaml",
      :http_method => "HEAD",
      :path => "/production/#{indirection.name}/unknown",
      :params => {},
      :client_cert => nil,
      :headers => {},
      :body => nil
    }
  end

  def a_request_that_heads(data, request = {})
    {
      :accept_header => request[:accept_header],
      :content_type_header => "text/yaml",
      :http_method => "HEAD",
      :path => "/production/#{indirection.name}/#{data.name}",
      :params => {},
      :client_cert => nil,
      :body => nil
    }
  end

  def a_request_that_submits(data, request = {})
    {
      :accept_header => request[:accept_header],
      :content_type_header => "text/yaml",
      :http_method => "PUT",
      :path => "/production/#{indirection.name}/#{data.name}",
      :params => {},
      :client_cert => nil,
      :body => data.render("text/yaml")
    }
  end

  def a_request_that_destroys(data, request = {})
    {
      :accept_header => request[:accept_header],
      :content_type_header => "text/yaml",
      :http_method => "DELETE",
      :path => "/production/#{indirection.name}/#{data.name}",
      :params => {},
      :client_cert => nil,
      :body => ''
    }
  end

  def a_request_that_finds(data, request = {})
    {
      :accept_header => request[:accept_header],
      :content_type_header => "text/yaml",
      :http_method => "GET",
      :path => "/production/#{indirection.name}/#{data.name}",
      :params => {},
      :client_cert => nil,
      :body => ''
    }
  end

  def a_request_that_searches(key, request = {})
    {
      :accept_header => request[:accept_header],
      :content_type_header => "text/yaml",
      :http_method => "GET",
      :path => "/production/#{indirection.name}s/#{key}",
      :params => {},
      :client_cert => nil,
      :body => ''
    }
  end

  let(:handler) { TestingHandler.new }

  it "should include the v1 REST API" do
    Puppet::Network::HTTP::Handler.ancestors.should be_include(Puppet::Network::HTTP::API::V1)
  end

  it "should include the Rest Authorization system" do
    Puppet::Network::HTTP::Handler.ancestors.should be_include(Puppet::Network::Authorization)
  end

  describe "when initializing" do
    it "should fail when no server type has been provided" do
      lambda { handler.initialize_for_puppet }.should raise_error(ArgumentError)
    end

    it "should set server type" do
      handler.initialize_for_puppet("foo")
      handler.server.should == "foo"
    end
  end

  describe "when processing a request" do
    let(:response) { mock('http response') }

    before do
      handler.stubs(:check_authorization)
      handler.stubs(:warn_if_near_expiration)
    end

    it "should check the client certificate for upcoming expiration" do
      request = a_request
      cert = mock 'cert'
      handler.stubs(:uri2indirection).returns(["facts", :mymethod, "key", {:node => "name"}])
      handler.expects(:client_cert).returns(cert).with(request)
      handler.expects(:warn_if_near_expiration).with(cert)

      handler.process(request, response)
    end

    it "should setup a profiler when the puppet-profiling header exists" do
      request = a_request
      request[:headers][Puppet::Network::HTTP::HEADER_ENABLE_PROFILING.downcase] = "true"

      handler.process(request, response)

      Puppet::Util::Profiler.current.should be_kind_of(Puppet::Util::Profiler::WallClock)
    end

    it "should not setup profiler when the profile parameter is missing" do
      request = a_request
      request[:params] = { }

      handler.process(request, response)

      Puppet::Util::Profiler.current.should == Puppet::Util::Profiler::NONE
    end

    it "should create an indirection request from the path, parameters, and http method" do
      request = a_request
      request[:path] = "mypath"
      request[:http_method] = "mymethod"
      request[:params] = { :params => "mine" }

      handler.expects(:uri2indirection).with("mymethod", "mypath", { :params => "mine" }).returns stub("request", :method => :find)

      handler.stubs(:do_find)

      handler.process(request, response)
    end

    it "should call the 'do' method and delegate authorization to the authorization layer" do
      request = a_request
      handler.expects(:uri2indirection).returns(["facts", :mymethod, "key", {:node => "name"}])

      handler.expects(:do_mymethod).with("facts", "key", {:node => "name"}, request, response)

      handler.expects(:check_authorization).with("facts", :mymethod, "key", {:node => "name"})

      handler.process(request, response)
    end

    it "should return 403 if the request is not authorized" do
      request = a_request
      handler.expects(:uri2indirection).returns(["facts", :mymethod, "key", {:node => "name"}])

      handler.expects(:do_mymethod).never

      handler.expects(:check_authorization).with("facts", :mymethod, "key", {:node => "name"}).raises(Puppet::Network::AuthorizationError.new("forbidden"))

      handler.expects(:set_response).with(anything, anything, 403)

      handler.process(request, response)
    end

    it "should serialize a controller exception when an exception is thrown while finding the model instance" do
      request = a_request
      handler.expects(:uri2indirection).returns(["facts", :find, "key", {:node => "name"}])

      handler.expects(:do_find).raises(ArgumentError, "The exception")
      handler.expects(:set_response).with(anything, "The exception", 400)
      handler.process(request, response)
    end

    it "should set the format to text/plain when serializing an exception" do
      handler.expects(:set_content_type).with(response, "text/plain")

      handler.do_exception(response, "A test", 404)
    end

    it "sends an exception string with the given status" do
      handler.expects(:set_response).with(response, "A test", 404)

      handler.do_exception(response, "A test", 404)
    end

    it "sends an exception error with the exception's status" do
      data = Puppet::TestModel.new("not_found", "not found")
      request = a_request_that_finds(data, :accept_header => "pson")

      error = Puppet::Network::HTTP::Handler::HTTPNotFoundError.new("Could not find test_model not_found")
      handler.expects(:set_response).with(response, error.to_s, error.status)

      handler.process(request, response)
    end

    it "should raise an error if the request is formatted in an unknown format" do
      handler.stubs(:content_type_header).returns "unknown format"
      lambda { handler.request_format(request) }.should raise_error
    end

    it "should still find the correct format if content type contains charset information" do
      request = a_request
      handler.stubs(:content_type_header).returns "text/plain; charset=UTF-8"
      handler.request_format(request).should == "s"
    end

    it "should deserialize YAML parameters" do
      params = {'my_param' => [1,2,3].to_yaml}

      decoded_params = handler.send(:decode_params, params)

      decoded_params.should == {:my_param => [1,2,3]}
    end

    it "should ignore tags on YAML parameters" do
      params = {'my_param' => "--- !ruby/object:Array {}"}

      decoded_params = handler.send(:decode_params, params)

      decoded_params[:my_param].should be_a(Hash)
    end

    describe "when finding a model instance" do
      it "uses the first supported format for the response" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_finds(data, :accept_header => "unknown, pson, yaml")

        handler.expects(:set_response).with(response, data.render(:pson))
        handler.expects(:set_content_type).with(response, Puppet::Network::FormatHandler.format(:pson))

        handler.do_find(indirection.name, "my data", {}, request, response)
      end

      it "responds with a 406 error when no accept header is provided" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_finds(data, :accept_header => nil)

        expect do
          handler.do_find(indirection.name, "my data", {}, request, response)
        end.to raise_error(Puppet::Network::HTTP::Handler::HTTPNotAcceptableError)
      end

      it "raises an error when no accepted formats are known" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_finds(data, :accept_header => "unknown, also/unknown")

        expect do
          handler.do_find(indirection.name, "my data", {}, request, response)
        end.to raise_error(Puppet::Network::HTTP::Handler::HTTPNotAcceptableError)
      end

      it "should pass the result through without rendering it if the result is a string" do
        data = Puppet::TestModel.new("my data", "some data")
        data_string = "my data string"
        request = a_request_that_finds(data, :accept_header => "pson")
        indirection.expects(:find).returns(data_string)

        handler.expects(:set_response).with(response, data_string)
        handler.expects(:set_content_type).with(response, Puppet::Network::FormatHandler.format(:pson))

        handler.do_find(indirection.name, "my data", {}, request, response)
      end

      it "should return a 404 when no model instance can be found" do
        data = Puppet::TestModel.new("my data", "some data")
        request = a_request_that_finds(data, :accept_header => "unknown, pson, yaml")

        expect do
          handler.do_find(indirection.name, "my data", {}, request, response)
        end.to raise_error(Puppet::Network::HTTP::Handler::HTTPNotFoundError)
      end
    end

    describe "when performing head operation" do
      it "should not generate a response when a model head call succeeds" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_heads(data)

        handler.expects(:set_response).never

        handler.process(request, response)
      end

      it "should return a 404 when the model head call returns false" do
        data = Puppet::TestModel.new("my data", "data not there")
        request = a_request_that_heads(data)

        handler.expects(:set_response).with(response, "Not Found: Could not find test_model my data", 404)

        handler.process(request, response)
      end
    end

    describe "when searching for model instances" do
      it "uses the first supported format for the response" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_searches("my", :accept_header => "unknown, pson, yaml")

        handler.expects(:set_response).with(response, Puppet::TestModel.render_multiple(:pson, [data]))
        handler.expects(:set_content_type).with(response, Puppet::Network::FormatHandler.format(:pson))

        handler.do_search(indirection.name, "my", {}, request, response)
      end

      it "should return [] when searching returns an empty array" do
        request = a_request_that_searches("nothing", :accept_header => "unknown, pson, yaml")

        handler.expects(:set_response).with(response, Puppet::TestModel.render_multiple(:pson, []))
        handler.expects(:set_content_type).with(response, Puppet::Network::FormatHandler.format(:pson))

        handler.do_search(indirection.name, "nothing", {}, request, response)
      end

      it "should return a 404 when searching returns nil" do
        request = a_request_that_searches("nothing", :accept_header => "unknown, pson, yaml")
        indirection.expects(:search).returns(nil)

        expect do
          handler.do_search(indirection.name, "nothing", {}, request, response)
        end.to raise_error(Puppet::Network::HTTP::Handler::HTTPNotFoundError)
      end
    end

    describe "when destroying a model instance" do
      it "destroys the data indicated in the request" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_destroys(data)

        handler.do_destroy(indirection.name, "my data", {}, request, response)

        Puppet::TestModel.indirection.find("my data").should be_nil
      end

      it "responds with yaml when no Accept header is given" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_destroys(data, :accept_header => nil)

        handler.expects(:set_response).with(response, data.render(:yaml))
        handler.expects(:set_content_type).with(response, Puppet::Network::FormatHandler.format(:yaml))

        handler.do_destroy(indirection.name, "my data", {}, request, response)
      end

      it "uses the first supported format for the response" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_destroys(data, :accept_header => "unknown, pson, yaml")

        handler.expects(:set_response).with(response, data.render(:pson))
        handler.expects(:set_content_type).with(response, Puppet::Network::FormatHandler.format(:pson))

        handler.do_destroy(indirection.name, "my data", {}, request, response)
      end

      it "raises an error and does not destory when no accepted formats are known" do
        data = Puppet::TestModel.new("my data", "some data")
        indirection.save(data, "my data")
        request = a_request_that_submits(data, :accept_header => "unknown, also/unknown")

        expect do
          handler.do_destroy(indirection.name, "my data", {}, request, response)
        end.to raise_error(Puppet::Network::HTTP::Handler::HTTPNotAcceptableError)

        Puppet::TestModel.indirection.find("my data").should_not be_nil
      end
    end

    describe "when saving a model instance" do
      it "should fail to save model if data is not specified" do
        data = Puppet::TestModel.new("my data", "some data")
        request = a_request_that_submits(data)
        request[:body] = ''

        expect { handler.do_save("my_handler", "my_result", {}, request, response) }.to raise_error(ArgumentError)
      end

      it "saves the data sent in the request" do
        data = Puppet::TestModel.new("my data", "some data")
        request = a_request_that_submits(data)

        handler.do_save(indirection.name, "my data", {}, request, response)

        Puppet::TestModel.indirection.find("my data").should == data
      end

      it "responds with yaml when no Accept header is given" do
        data = Puppet::TestModel.new("my data", "some data")
        request = a_request_that_submits(data, :accept_header => nil)

        handler.expects(:set_response).with(response, data.render(:yaml))
        handler.expects(:set_content_type).with(response, Puppet::Network::FormatHandler.format(:yaml))

        handler.do_save(indirection.name, "my data", {}, request, response)
      end

      it "uses the first supported format for the response" do
        data = Puppet::TestModel.new("my data", "some data")
        request = a_request_that_submits(data, :accept_header => "unknown, pson, yaml")

        handler.expects(:set_response).with(response, data.render(:pson))
        handler.expects(:set_content_type).with(response, Puppet::Network::FormatHandler.format(:pson))

        handler.do_save(indirection.name, "my data", {}, request, response)
      end

      it "raises an error and does not save when no accepted formats are known" do
        data = Puppet::TestModel.new("my data", "some data")
        request = a_request_that_submits(data, :accept_header => "unknown, also/unknown")

        expect do
          handler.do_save(indirection.name, "my data", {}, request, response)
        end.to raise_error(Puppet::Network::HTTP::Handler::HTTPNotAcceptableError)

        Puppet::TestModel.indirection.find("my data").should be_nil
      end
    end
  end

  describe "when resolving node" do
    it "should use a look-up from the ip address" do
      Resolv.expects(:getname).with("1.2.3.4").returns("host.domain.com")

      handler.resolve_node(:ip => "1.2.3.4")
    end

    it "should return the look-up result" do
      Resolv.stubs(:getname).with("1.2.3.4").returns("host.domain.com")

      handler.resolve_node(:ip => "1.2.3.4").should == "host.domain.com"
    end

    it "should return the ip address if resolving fails" do
      Resolv.stubs(:getname).with("1.2.3.4").raises(RuntimeError, "no such host")

      handler.resolve_node(:ip => "1.2.3.4").should == "1.2.3.4"
    end
  end

  class TestingHandler
    include Puppet::Network::HTTP::Handler

    def accept_header(request)
      request[:accept_header]
    end

    def content_type_header(request)
      request[:content_type_header]
    end

    def set_content_type(response, format)
      "my_result"
    end

    def set_response(response, body, status = 200)
      "my_result"
    end

    def http_method(request)
      request[:http_method]
    end

    def path(request)
      request[:path]
    end

    def params(request)
      request[:params]
    end

    def client_cert(request)
      request[:client_cert]
    end

    def body(request)
      request[:body]
    end

    def headers(request)
      request[:headers] || {}
    end
  end
end
