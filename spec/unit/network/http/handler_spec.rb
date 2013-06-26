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

  def a_request_that_submits(data, request = {})
    {
      :accept_header => request[:accept_header],
      :content_type_header => "text/yaml",
      :http_method => "GET",
      :path => "/#{indirection.name}/#{data.name}",
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
      :path => "/#{indirection.name}/#{data.name}",
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
    let(:request) do
      {
        :accept_header => "format_one,format_two",
        :content_type_header => "text/yaml",
        :http_method => "GET",
        :path => "/my_handler/my_result",
        :params => {},
        :client_cert => nil
      }
    end

    let(:response) { mock('http response') }

    before do
      @model_class = stub('indirected model class')
      @indirection = stub('indirection')
      @model_class.stubs(:indirection).returns(@indirection)

      @result = stub 'result', :render => "mytext"

      request[:headers] = {
          "Content-Type"  => request[:content_type_header],
          "Accept"        => request[:accept_header]
      }

      handler.stubs(:check_authorization)
      handler.stubs(:warn_if_near_expiration)
      handler.stubs(:headers).returns(request[:headers])
    end

    it "should check the client certificate for upcoming expiration" do
      cert = mock 'cert'
      handler.stubs(:uri2indirection).returns(["facts", :mymethod, "key", {:node => "name"}])
      handler.expects(:client_cert).returns(cert).with(request)
      handler.expects(:warn_if_near_expiration).with(cert)

      handler.process(request, response)
    end

    it "should setup a profiler when the puppet-profiling header exists" do
      request[:headers][Puppet::Network::HTTP::HEADER_ENABLE_PROFILING.downcase] = "true"

      handler.process(request, response)

      Puppet::Util::Profiler.current.should be_kind_of(Puppet::Util::Profiler::WallClock)
    end

    it "should not setup profiler when the profile parameter is missing" do
      request[:params] = { }

      handler.process(request, response)

      Puppet::Util::Profiler.current.should == Puppet::Util::Profiler::NONE
    end

    it "should create an indirection request from the path, parameters, and http method" do
      request[:path] = "mypath"
      request[:http_method] = "mymethod"
      request[:params] = { :params => "mine" }

      handler.expects(:uri2indirection).with("mymethod", "mypath", { :params => "mine" }).returns stub("request", :method => :find)

      handler.stubs(:do_find)

      handler.process(request, response)
    end

    it "should call the 'do' method and delegate authorization to the authorization layer" do
      handler.expects(:uri2indirection).returns(["facts", :mymethod, "key", {:node => "name"}])

      handler.expects(:do_mymethod).with("facts", "key", {:node => "name"}, request, response)

      handler.expects(:check_authorization).with("facts", :mymethod, "key", {:node => "name"})

      handler.process(request, response)
    end

    it "should return 403 if the request is not authorized" do
      handler.expects(:uri2indirection).returns(["facts", :mymethod, "key", {:node => "name"}])

      handler.expects(:do_mymethod).never

      handler.expects(:check_authorization).with("facts", :mymethod, "key", {:node => "name"}).raises(Puppet::Network::AuthorizationError.new("forbidden"))

      handler.expects(:set_response).with(anything, anything, 403)

      handler.process(request, response)
    end

    it "should serialize a controller exception when an exception is thrown while finding the model instance" do
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
      error = Puppet::Network::HTTP::Handler::HTTPNotAcceptableError.new("test message")

      handler.expects(:set_response).with(response, error.to_s, error.status)

      handler.do_exception(response, error)
    end

    it "should raise an error if the request is formatted in an unknown format" do
      handler.stubs(:content_type_header).returns "unknown format"
      lambda { handler.request_format(request) }.should raise_error
    end

    it "should still find the correct format if content type contains charset information" do
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
      before do
        @indirection.stubs(:find).returns @result
        Puppet::Indirector::Indirection.expects(:instance).with(:my_handler).returns( stub "indirection", :model => @model_class )

        @format = stub 'format', :suitable? => true, :mime => "text/format", :name => "format"
        Puppet::Network::FormatHandler.stubs(:format).returns @format

        @oneformat = stub 'one', :suitable? => true, :mime => "text/one", :name => "one"
        Puppet::Network::FormatHandler.stubs(:format).with("one").returns @oneformat
      end

      it "should use the indirection request to find the model class" do
        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should use the escaped request key" do
        @indirection.expects(:find).with("my_result", anything).returns @result
        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should use a common method for determining the request parameters" do
        @indirection.expects(:find).with(anything, has_entries(:foo => :baz, :bar => :xyzzy)).returns @result

        handler.do_find("my_handler", "my_result", {:foo => :baz, :bar => :xyzzy}, request, response)
      end

      it "should set the content type to the first format specified in the accept header" do
        handler.expects(:accept_header).with(request).returns "one,two"
        handler.expects(:set_content_type).with(response, @oneformat)
        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should fail if no accept header is provided" do
        handler.expects(:accept_header).with(request).returns nil
        lambda { handler.do_find("my_handler", "my_result", {}, request, response) }.should raise_error(ArgumentError)
      end

      it "should fail if the accept header does not contain a valid format" do
        handler.expects(:accept_header).with(request).returns ""
        lambda { handler.do_find("my_handler", "my_result", {}, request, response) }.should raise_error(RuntimeError)
      end

      it "should not use an unsuitable format" do
        handler.expects(:accept_header).with(request).returns "foo,bar"
        foo = mock 'foo', :suitable? => false
        bar = mock 'bar', :suitable? => true
        Puppet::Network::FormatHandler.expects(:format).with("foo").returns foo
        Puppet::Network::FormatHandler.expects(:format).with("bar").returns bar

        handler.expects(:set_content_type).with(response, bar) # the suitable one

        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should render the result using the first format specified in the accept header" do

        handler.expects(:accept_header).with(request).returns "one,two"
        @result.expects(:render).with(@oneformat)

        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should pass the result through without rendering it if the result is a string" do
        @indirection.stubs(:find).returns "foo"
        handler.expects(:set_response).with(response, "foo")
        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should use the default status when a model find call succeeds" do
        handler.expects(:set_response).with(anything, anything, nil)
        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should return a serialized object when a model find call succeeds" do
        @model_instance = stub('model instance')
        @model_instance.expects(:render).returns "my_rendered_object"

        handler.expects(:set_response).with(anything, "my_rendered_object", anything)
        @indirection.stubs(:find).returns(@model_instance)
        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should return a 404 when no model instance can be found" do
        @model_class.stubs(:name).returns "my name"
        handler.expects(:set_response).with(anything, anything, 404)
        @indirection.stubs(:find).returns(nil)
        handler.do_find("my_handler", "my_result", {}, request, response)
      end

      it "should write a log message when no model instance can be found" do
        @model_class.stubs(:name).returns "my name"
        @indirection.stubs(:find).returns(nil)

        Puppet.expects(:info).with("Could not find my_handler for 'my_result'")

        handler.do_find("my_handler", "my_result", {}, request, response)
      end


      it "should serialize the result in with the appropriate format" do
        @model_instance = stub('model instance')

        handler.expects(:format_to_use).returns(@oneformat)
        @model_instance.expects(:render).with(@oneformat).returns "my_rendered_object"
        @indirection.stubs(:find).returns(@model_instance)
        handler.do_find("my_handler", "my_result", {}, request, response)
      end
    end

    describe "when performing head operation" do
      before do
        handler.stubs(:model).with("my_handler").returns(stub 'model', :indirection => @model_class)
        request[:http_method] = "HEAD"
        request[:path] = "/production/my_handler/my_result"
        request[:params] = {}

        @model_class.stubs(:head).returns true
      end

      it "should use the escaped request key" do
        @model_class.expects(:head).with("my_result", anything).returns true
        handler.process(request, response)
      end

      it "should not generate a response when a model head call succeeds" do
        handler.expects(:set_response).never
        handler.process(request, response)
      end

      it "should return a 404 when the model head call returns false" do
        handler.expects(:set_response).with(anything, anything, 404)
        @model_class.stubs(:head).returns(false)
        handler.process(request, response)
      end
    end

    describe "when searching for model instances" do
      before do
        Puppet::Indirector::Indirection.expects(:instance).with(:my_handler).returns( stub "indirection", :model => @model_class )

        result1 = mock 'result1'
        result2 = mock 'results'

        @result = [result1, result2]
        @model_class.stubs(:render_multiple).returns "my rendered instances"
        @indirection.stubs(:search).returns(@result)

        @format = stub 'format', :suitable? => true, :mime => "text/format", :name => "format"
        Puppet::Network::FormatHandler.stubs(:format).returns @format

        @oneformat = stub 'one', :suitable? => true, :mime => "text/one", :name => "one"
        Puppet::Network::FormatHandler.stubs(:format).with("one").returns @oneformat
      end

      it "should use the indirection request to find the model" do
        handler.do_search("my_handler", "my_result", {}, request, response)
      end

      it "should use a common method for determining the request parameters" do
        @indirection.expects(:search).with(anything, has_entries(:foo => :baz, :bar => :xyzzy)).returns @result
        handler.do_search("my_handler", "my_result", {:foo => :baz, :bar => :xyzzy}, request, response)
      end

      it "should use the default status when a model search call succeeds" do
        @indirection.stubs(:search).returns(@result)
        handler.do_search("my_handler", "my_result", {}, request, response)
      end

      it "should set the content type to the first format returned by the accept header" do
        handler.expects(:accept_header).with(request).returns "one,two"
        handler.expects(:set_content_type).with(response, @oneformat)

        handler.do_search("my_handler", "my_result", {}, request, response)
      end

      it "should return a list of serialized objects when a model search call succeeds" do
        handler.expects(:accept_header).with(request).returns "one,two"

        @indirection.stubs(:search).returns(@result)

        @model_class.expects(:render_multiple).with(@oneformat, @result).returns "my rendered instances"

        handler.expects(:set_response).with(anything, "my rendered instances")
        handler.do_search("my_handler", "my_result", {}, request, response)
      end

      it "should return [] when searching returns an empty array" do
        handler.expects(:accept_header).with(request).returns "one,two"
        @indirection.stubs(:search).returns([])
        @model_class.expects(:render_multiple).with(@oneformat, []).returns "[]"


        handler.expects(:set_response).with(anything, "[]")
        handler.do_search("my_handler", "my_result", {}, request, response)
      end

      it "should return a 404 when searching returns nil" do
        @model_class.stubs(:name).returns "my name"
        handler.expects(:set_response).with(anything, anything, 404)
        @indirection.stubs(:search).returns(nil)
        handler.do_search("my_handler", "my_result", {}, request, response)
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
  end
end
