#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/network/http/handler'

class HttpHandled
    include Puppet::Network::HTTP::Handler
end

describe Puppet::Network::HTTP::Handler do
    before do
        @handler = HttpHandled.new
    end

    it "should be able to convert a URI into a request" do
        @handler.should respond_to(:uri2indirection)
    end

    it "should be able to convert a request into a URI" do
        @handler.should respond_to(:indirection2uri)
    end

    describe "when converting a URI into a request" do
        before do
            @handler.stubs(:handler).returns "foo"
        end

        it "should require the http method, the URI, and the query parameters" do
            # Not a terribly useful test, but an important statement for the spec
            lambda { @handler.uri2indirection("/foo") }.should raise_error(ArgumentError)
        end

        it "should use the first field of the URI as the environment" do
            @handler.uri2indirection("GET", "/env/foo/bar", {}).environment.should == Puppet::Node::Environment.new("env")
        end

        it "should fail if the environment is not alphanumeric" do
            lambda { @handler.uri2indirection("GET", "/env ness/foo/bar", {}) }.should raise_error(ArgumentError)
        end

        it "should use the environment from the URI even if one is specified in the parameters" do
            @handler.uri2indirection("GET", "/env/foo/bar", {:environment => "otherenv"}).environment.should == Puppet::Node::Environment.new("env")
        end

        it "should use the second field of the URI as the indirection name" do
            @handler.uri2indirection("GET", "/env/foo/bar", {}).indirection_name.should == :foo
        end

        it "should fail if the indirection name is not alphanumeric" do
            lambda { @handler.uri2indirection("GET", "/env/foo ness/bar", {}) }.should raise_error(ArgumentError)
        end

        it "should use the remainder of the URI as the indirection key" do
            @handler.uri2indirection("GET", "/env/foo/bar", {}).key.should == "bar"
        end

        it "should support the indirection key being a /-separated file path" do
            @handler.uri2indirection("GET", "/env/foo/bee/baz/bomb", {}).key.should == "bee/baz/bomb"
        end

        it "should fail if no indirection key is specified" do
            lambda { @handler.uri2indirection("GET", "/env/foo/", {}) }.should raise_error(ArgumentError)
            lambda { @handler.uri2indirection("GET", "/env/foo", {}) }.should raise_error(ArgumentError)
        end

        it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is singular" do
            @handler.uri2indirection("GET", "/env/foo/bar", {}).method.should == :find
        end

        it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is plural" do
            @handler.uri2indirection("GET", "/env/foos/bar", {}).method.should == :search
        end

        it "should choose 'delete' as the indirection method if the http method is a DELETE and the indirection name is singular" do
            @handler.uri2indirection("DELETE", "/env/foo/bar", {}).method.should == :destroy
        end

        it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is singular" do
            @handler.uri2indirection("PUT", "/env/foo/bar", {}).method.should == :save
        end

        it "should fail if an indirection method cannot be picked" do
            lambda { @handler.uri2indirection("UPDATE", "/env/foo/bar", {}) }.should raise_error(ArgumentError)
        end

        it "should URI unescape the indirection key" do
            escaped = URI.escape("foo bar")
            @handler.uri2indirection("GET", "/env/foo/#{escaped}", {}).key.should == "foo bar"
        end
    end

    describe "when converting a request into a URI" do
        before do
            @request = Puppet::Indirector::Request.new(:foo, :find, "with spaces", :foo => :bar, :environment => "myenv")
        end

        it "should use the environment as the first field of the URI" do
            @handler.indirection2uri(@request).split("/")[1].should == "myenv"
        end

        it "should use the indirection as the second field of the URI" do
            @handler.indirection2uri(@request).split("/")[2].should == "foo"
        end

        it "should pluralize the indirection name if the method is 'search'" do
            @request.stubs(:method).returns :search
            @handler.indirection2uri(@request).split("/")[2].should == "foos"
        end

        it "should use the escaped key as the remainder of the URI" do
            escaped = URI.escape("with spaces")
            @handler.indirection2uri(@request).split("/")[3].sub(/\?.+/, '').should == escaped
        end

        it "should add the query string to the URI" do
            @request.expects(:query_string).returns "?query"
            @handler.indirection2uri(@request).should =~ /\?query$/
        end
    end

    it "should have a method for initializing" do
        @handler.should respond_to(:initialize_for_puppet)
    end

    describe "when initializing" do
        before do
            Puppet::Indirector::Indirection.stubs(:model).returns "eh"
        end

        it "should fail when no server type has been provided" do
            lambda { @handler.initialize_for_puppet :handler => "foo" }.should raise_error(ArgumentError)
        end

        it "should fail when no handler has been provided" do
            lambda { @handler.initialize_for_puppet :server => "foo" }.should raise_error(ArgumentError)
        end

        it "should set the handler and server type" do
            @handler.initialize_for_puppet :server => "foo", :handler => "bar"
            @handler.server.should == "foo"
            @handler.handler.should == "bar"
        end

        it "should use the indirector to find the appropriate model" do
            Puppet::Indirector::Indirection.expects(:model).with("bar").returns "mymodel"
            @handler.initialize_for_puppet :server => "foo", :handler => "bar"
            @handler.model.should == "mymodel"
        end
    end

    it "should be able to process requests" do
        @handler.should respond_to(:process)
    end

    describe "when processing a request" do
        before do
            @request     = stub('http request')
            @request.stubs(:[]).returns "foo"
            @response    = stub('http response')
            @model_class = stub('indirected model class')

            @result = stub 'result', :render => "mytext"

            @handler.stubs(:model).returns @model_class
            @handler.stubs(:handler).returns :my_handler

            stub_server_interface
        end

        # Stub out the interface we require our including classes to
        # implement.
        def stub_server_interface
            @handler.stubs(:accept_header   ).returns "format_one,format_two"
            @handler.stubs(:set_content_type).returns "my_result"
            @handler.stubs(:set_response    ).returns "my_result"
            @handler.stubs(:path            ).returns "/my_handler/my_result"
            @handler.stubs(:http_method     ).returns("GET")
            @handler.stubs(:params          ).returns({})
            @handler.stubs(:content_type    ).returns("text/plain")
        end

        it "should create an indirection request from the path, parameters, and http method" do
            @handler.expects(:path).with(@request).returns "mypath"
            @handler.expects(:http_method).with(@request).returns "mymethod"
            @handler.expects(:params).with(@request).returns "myparams"

            @handler.expects(:uri2indirection).with("mypath", "myparams", "mymethod").returns stub("request", :method => :find)

            @handler.stubs(:do_find)

            @handler.process(@request, @response)
        end

        it "should call the 'do' method associated with the indirection method" do
            request = stub 'request'
            @handler.expects(:uri2indirection).returns request

            request.expects(:method).returns "mymethod"

            @handler.expects(:do_mymethod).with(request, @request, @response)

            @handler.process(@request, @response)
        end

        it "should serialize a controller exception when an exception is thrown while finding the model instance" do
            @handler.expects(:uri2indirection).returns stub("request", :method => :find)

            @handler.expects(:do_find).raises(ArgumentError, "The exception")
            @handler.expects(:set_response).with { |response, body, status| body == "The exception" and status == 400 }
            @handler.process(@request, @response)
        end

        it "should set the format to text/plain when serializing an exception" do
            @handler.expects(:set_content_type).with(@response, "text/plain")
            @handler.do_exception(@response, "A test", 404)
        end

        describe "when finding a model instance" do
            before do
                @irequest = stub 'indirection_request', :method => :find, :indirection_name => "my_handler", :options => {}, :key => "my_result"

                @model_class.stubs(:find).returns @result

                @format = stub 'format', :suitable? => true
                Puppet::Network::FormatHandler.stubs(:format).returns @format
            end

            it "should use the escaped request key" do
                @model_class.expects(:find).with do |key, args|
                    key == "my_result"
                end.returns @result
                @handler.do_find(@irequest, @request, @response)
            end

            it "should use a common method for determining the request parameters" do
                @irequest.stubs(:options).returns(:foo => :baz, :bar => :xyzzy)
                @model_class.expects(:find).with do |key, args|
                    args[:foo] == :baz and args[:bar] == :xyzzy
                end.returns @result
                @handler.do_find(@irequest, @request, @response)
            end

            it "should set the content type to the first format specified in the accept header" do
                @handler.expects(:accept_header).with(@request).returns "one,two"
                @handler.expects(:set_content_type).with(@response, "one")
                @handler.do_find(@irequest, @request, @response)
            end

            it "should fail if no accept header is provided" do
                @handler.expects(:accept_header).with(@request).returns nil
                lambda { @handler.do_find(@irequest, @request, @response) }.should raise_error(ArgumentError)
            end

            it "should fail if the accept header does not contain a valid format" do
                @handler.expects(:accept_header).with(@request).returns ""
                lambda { @handler.do_find(@irequest, @request, @response) }.should raise_error(RuntimeError)
            end

            it "should not use an unsuitable format" do
                @handler.expects(:accept_header).with(@request).returns "foo,bar"
                foo = mock 'foo', :suitable? => false
                bar = mock 'bar', :suitable? => true
                Puppet::Network::FormatHandler.expects(:format).with("foo").returns foo
                Puppet::Network::FormatHandler.expects(:format).with("bar").returns bar

                @handler.expects(:set_content_type).with(@response, "bar") # the suitable one

                @handler.do_find(@irequest, @request, @response)
            end

            it "should render the result using the first format specified in the accept header" do
                @handler.expects(:accept_header).with(@request).returns "one,two"
                @result.expects(:render).with("one")

                @handler.do_find(@irequest, @request, @response)
            end

            it "should use the default status when a model find call succeeds" do
                @handler.expects(:set_response).with { |response, body, status| status.nil? }
                @handler.do_find(@irequest, @request, @response)
            end

            it "should return a serialized object when a model find call succeeds" do
                @model_instance = stub('model instance')
                @model_instance.expects(:render).returns "my_rendered_object"

                @handler.expects(:set_response).with { |response, body, status| body == "my_rendered_object" }
                @model_class.stubs(:find).returns(@model_instance)
                @handler.do_find(@irequest, @request, @response)
            end

            it "should return a 404 when no model instance can be found" do
                @model_class.stubs(:name).returns "my name"
                @handler.expects(:set_response).with { |response, body, status| status == 404 }
                @model_class.stubs(:find).returns(nil)
                @handler.do_find(@irequest, @request, @response)
            end

            it "should serialize the result in with the appropriate format" do
                @model_instance = stub('model instance')

                @handler.expects(:format_to_use).returns "one"
                @model_instance.expects(:render).with("one").returns "my_rendered_object"
                @model_class.stubs(:find).returns(@model_instance)
                @handler.do_find(@irequest, @request, @response)
            end
        end

        describe "when searching for model instances" do
            before do
                @irequest = stub 'indirection_request', :method => :find, :indirection_name => "my_handler", :options => {}, :key => "key"

                @result1 = mock 'result1'
                @result2 = mock 'results'

                @result = [@result1, @result2]
                @model_class.stubs(:render_multiple).returns "my rendered instances"
                @model_class.stubs(:search).returns(@result)

                @format = stub 'format', :suitable? => true
                Puppet::Network::FormatHandler.stubs(:format).returns @format
            end

            it "should use a common method for determining the request parameters" do
                @irequest.stubs(:options).returns(:foo => :baz, :bar => :xyzzy)
                @model_class.expects(:search).with do |key, args|
                    args[:foo] == :baz and args[:bar] == :xyzzy
                end.returns @result
                @handler.do_search(@irequest, @request, @response)
            end

            it "should use the default status when a model search call succeeds" do
                @model_class.stubs(:search).returns(@result)
                @handler.do_search(@irequest, @request, @response)
            end

            it "should set the content type to the first format returned by the accept header" do
                @handler.expects(:accept_header).with(@request).returns "one,two"
                @handler.expects(:set_content_type).with(@response, "one")

                @handler.do_search(@irequest, @request, @response)
            end

            it "should return a list of serialized objects when a model search call succeeds" do
                @handler.expects(:accept_header).with(@request).returns "one,two"

                @model_class.stubs(:search).returns(@result)

                @model_class.expects(:render_multiple).with("one", @result).returns "my rendered instances"

                @handler.expects(:set_response).with { |response, data| data == "my rendered instances" }
                @handler.do_search(@irequest, @request, @response)
            end

            it "should return a 404 when searching returns an empty array" do
                @model_class.stubs(:name).returns "my name"
                @handler.expects(:set_response).with { |response, body, status| status == 404 }
                @model_class.stubs(:search).returns([])
                @handler.do_search(@irequest, @request, @response)
            end

            it "should return a 404 when searching returns nil" do
                @model_class.stubs(:name).returns "my name"
                @handler.expects(:set_response).with { |response, body, status| status == 404 }
                @model_class.stubs(:search).returns([])
                @handler.do_search(@irequest, @request, @response)
            end
        end

        describe "when destroying a model instance" do
            before do
                @irequest = stub 'indirection_request', :method => :destroy, :indirection_name => "my_handler", :options => {}, :key => "key"

                @result = stub 'result', :render => "the result"
                @model_class.stubs(:destroy).returns @result
            end

            it "should use the escaped request key to destroy the instance in the model" do
                @irequest.expects(:key).returns "foo bar"
                @model_class.expects(:destroy).with do |key, args|
                    key == "foo bar"
                end
                @handler.do_destroy(@irequest, @request, @response)
            end

            it "should use a common method for determining the request parameters" do
                @irequest.stubs(:options).returns(:foo => :baz, :bar => :xyzzy)
                @model_class.expects(:destroy).with do |key, args|
                    args[:foo] == :baz and args[:bar] == :xyzzy
                end
                @handler.do_destroy(@irequest, @request, @response)
            end

            it "should use the default status code a model destroy call succeeds" do
                @handler.expects(:set_response).with { |response, body, status| status.nil? }
                @handler.do_destroy(@irequest, @request, @response)
            end

            it "should return a yaml-encoded result when a model destroy call succeeds" do
                @result = stub 'result', :to_yaml => "the result"
                @model_class.expects(:destroy).returns(@result)

                @handler.expects(:set_response).with { |response, body, status| body == "the result" }

                @handler.do_destroy(@irequest, @request, @response)
            end
        end

        describe "when saving a model instance" do
            before do
                @irequest = stub 'indirection_request', :method => :save, :indirection_name => "my_handler", :options => {}, :key => "key"
                @handler.stubs(:body).returns('my stuff')

                @result = stub 'result', :render => "the result"

                @model_instance = stub('indirected model instance', :save => true)
                @model_class.stubs(:convert_from).returns(@model_instance)

                @format = stub 'format', :suitable? => true
                Puppet::Network::FormatHandler.stubs(:format).returns @format
            end

            it "should use the 'body' hook to retrieve the body of the request" do
                @handler.expects(:body).returns "my body"
                @model_class.expects(:convert_from).with { |format, body| body == "my body" }.returns @model_instance

                @handler.do_save(@irequest, @request, @response)
            end

            it "should fail to save model if data is not specified" do
                @handler.stubs(:body).returns('')

                lambda { @handler.do_save(@irequest, @request, @response) }.should raise_error(ArgumentError)
            end

            it "should use a common method for determining the request parameters" do
                @irequest.stubs(:options).returns(:foo => :baz, :bar => :xyzzy)
                @model_instance.expects(:save).with do |args|
                    args[:foo] == :baz and args[:bar] == :xyzzy
                end
                @handler.do_save(@irequest, @request, @response)
            end

            it "should use the default status when a model save call succeeds" do
                @handler.expects(:set_response).with { |response, body, status| status.nil? }
                @handler.do_save(@irequest, @request, @response)
            end

            it "should return the yaml-serialized result when a model save call succeeds" do
                @model_instance.stubs(:save).returns(@model_instance)
                @model_instance.expects(:to_yaml).returns('foo')
                @handler.do_save(@irequest, @request, @response)
            end

            it "should set the content to yaml" do
                @handler.expects(:set_content_type).with(@response, "yaml")
                @handler.do_save(@irequest, @request, @response)
            end
        end
    end
end
