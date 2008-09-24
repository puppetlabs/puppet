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
            @handler.stubs(:path            ).returns "/my_handler"
            @handler.stubs(:request_key     ).returns "my_result"
            @handler.stubs(:params          ).returns({})
            @handler.stubs(:content_type    ).returns("text/plain")
        end

        it "should consider the request singular if the path is equal to '/' plus the handler name" do
            @handler.expects(:path).with(@request).returns "/foo"
            @handler.expects(:handler).returns "foo"

            @handler.should be_singular(@request)
        end

        it "should not consider the request singular unless the path is equal to '/' plus the handler name" do
            @handler.expects(:path).with(@request).returns "/foo"
            @handler.expects(:handler).returns "bar"

            @handler.should_not be_singular(@request)
        end

        it "should consider the request plural if the path is equal to '/' plus the handler name plus 's'" do
            @handler.expects(:path).with(@request).returns "/foos"
            @handler.expects(:handler).returns "foo"

            @handler.should be_plural(@request)
        end

        it "should not consider the request plural unless the path is equal to '/' plus the handler name plus 's'" do
            @handler.expects(:path).with(@request).returns "/foos"
            @handler.expects(:handler).returns "bar"

            @handler.should_not be_plural(@request)
        end

        it "should call the model find method if the request represents a singular HTTP GET" do
            @handler.expects(:http_method).returns('GET')
            @handler.expects(:singular?).returns(true)

            @handler.expects(:do_find).with(@request, @response)
            @handler.process(@request, @response)
        end

        it "should serialize a controller exception when an exception is thrown while finding the model instance" do
            @handler.expects(:http_method).returns('GET')
            @handler.expects(:singular?).returns(true)

            @handler.expects(:do_find).raises(ArgumentError, "The exception")
            @handler.expects(:set_response).with { |response, body, status| body == "The exception" and status == 400 }
            @handler.process(@request, @response)
        end

        it "should call the model search method if the request represents a plural HTTP GET" do
            @handler.stubs(:http_method).returns('GET')
            @handler.stubs(:singular?).returns(false)
            @handler.stubs(:plural?).returns(true)

            @handler.expects(:do_search).with(@request, @response)
            @handler.process(@request, @response)
        end

        it "should serialize a controller exception when an exception is thrown by search" do
            @handler.stubs(:http_method).returns('GET')
            @handler.stubs(:singular?).returns(false)
            @handler.stubs(:plural?).returns(true)

            @model_class.expects(:search).raises(ArgumentError)
            @handler.expects(:set_response).with { |response, data, status| status == 400 }
            @handler.process(@request, @response)
        end

        it "should call the model destroy method if the request represents an HTTP DELETE" do
            @handler.stubs(:http_method).returns('DELETE')
            @handler.stubs(:singular?).returns(true)
            @handler.stubs(:plural?).returns(false)

            @handler.expects(:do_destroy).with(@request, @response)

            @handler.process(@request, @response)
        end

        it "should serialize a controller exception when an exception is thrown by destroy" do
            @handler.stubs(:http_method).returns('DELETE')
            @handler.stubs(:singular?).returns(true)
            @handler.stubs(:plural?).returns(false)

            @handler.expects(:do_destroy).with(@request, @response).raises(ArgumentError, "The exception")
            @handler.expects(:set_response).with { |response, body, status| body == "The exception" and status == 400 }

            @handler.process(@request, @response)
        end

        it "should call the model save method if the request represents an HTTP PUT" do
            @handler.stubs(:http_method).returns('PUT')
            @handler.stubs(:singular?).returns(true)

            @handler.expects(:do_save).with(@request, @response)

            @handler.process(@request, @response)
        end

        it "should serialize a controller exception when an exception is thrown by save" do
            @handler.stubs(:http_method).returns('PUT')
            @handler.stubs(:singular?).returns(true)
            @handler.stubs(:body).raises(ArgumentError)

            @handler.expects(:set_response).with { |response, body, status| status == 400 }
            @handler.process(@request, @response)
        end

        it "should fail if the HTTP method isn't supported" do
            @handler.stubs(:http_method).returns('POST')
            @handler.stubs(:singular?).returns(true)
            @handler.stubs(:plural?).returns(false)

            @handler.expects(:set_response).with { |response, body, status| status == 400 }
            @handler.process(@request, @response)
        end

        it "should fail if delete request's pluralization is wrong" do
            @handler.stubs(:http_method).returns('DELETE')
            @handler.stubs(:singular?).returns(false)
            @handler.stubs(:plural?).returns(true)

            @handler.expects(:set_response).with { |response, body, status| status == 400 }
            @handler.process(@request, @response)
        end

        it "should fail if put request's pluralization is wrong" do
            @handler.stubs(:http_method).returns('PUT')
            @handler.stubs(:singular?).returns(false)
            @handler.stubs(:plural?).returns(true)

            @handler.expects(:set_response).with { |response, body, status| status == 400 }
            @handler.process(@request, @response)
        end

        it "should fail if the request is for an unknown path" do
            @handler.stubs(:http_method).returns('GET')
            @handler.expects(:singular?).returns false
            @handler.expects(:plural?).returns false

            @handler.expects(:set_response).with { |response, body, status| status == 400 }
            @handler.process(@request, @response)
        end

        it "should set the format to text/plain when serializing an exception" do
            @handler.expects(:set_content_type).with(@response, "text/plain")
            @handler.do_exception(@response, "A test", 404)
        end

        describe "when finding a model instance" do
            before do
                @handler.stubs(:http_method).returns('GET')
                @handler.stubs(:path).returns('/my_handler')
                @handler.stubs(:singular?).returns(true)
                @handler.stubs(:request_key).returns('key')
                @model_class.stubs(:find).returns @result

                @format = stub 'format', :suitable? => true
                Puppet::Network::FormatHandler.stubs(:format).returns @format
            end

            it "should fail to find model if key is not specified" do
                @handler.stubs(:request_key).returns(nil)

                lambda { @handler.do_find(@request, @response) }.should raise_error(ArgumentError)
            end

            it "should use a common method for determining the request parameters" do
                @handler.stubs(:params).returns(:foo => :baz, :bar => :xyzzy)
                @model_class.expects(:find).with do |key, args|
                    args[:foo] == :baz and args[:bar] == :xyzzy
                end.returns @result
                @handler.do_find(@request, @response)
            end

            it "should set the content type to the first format specified in the accept header" do
                @handler.expects(:accept_header).with(@request).returns "one,two"
                @handler.expects(:set_content_type).with(@response, "one")
                @handler.do_find(@request, @response)
            end

            it "should fail if no accept header is provided" do
                @handler.expects(:accept_header).with(@request).returns nil
                lambda { @handler.do_find(@request, @response) }.should raise_error(ArgumentError)
            end

            it "should fail if the accept header does not contain a valid format" do
                @handler.expects(:accept_header).with(@request).returns ""
                lambda { @handler.do_find(@request, @response) }.should raise_error(RuntimeError)
            end

            it "should not use an unsuitable format" do
                @handler.expects(:accept_header).with(@request).returns "foo,bar"
                foo = mock 'foo', :suitable? => false
                bar = mock 'bar', :suitable? => true
                Puppet::Network::FormatHandler.expects(:format).with("foo").returns foo
                Puppet::Network::FormatHandler.expects(:format).with("bar").returns bar

                @handler.expects(:set_content_type).with(@response, "bar") # the suitable one

                @handler.do_find(@request, @response)
            end

            it "should render the result using the first format specified in the accept header" do
                @handler.expects(:accept_header).with(@request).returns "one,two"
                @result.expects(:render).with("one")

                @handler.do_find(@request, @response)
            end

            it "should use the default status when a model find call succeeds" do
                @handler.expects(:set_response).with { |response, body, status| status.nil? }
                @handler.do_find(@request, @response)
            end

            it "should return a serialized object when a model find call succeeds" do
                @model_instance = stub('model instance')
                @model_instance.expects(:render).returns "my_rendered_object"

                @handler.expects(:set_response).with { |response, body, status| body == "my_rendered_object" }
                @model_class.stubs(:find).returns(@model_instance)
                @handler.do_find(@request, @response)
            end

            it "should return a 404 when no model instance can be found" do
                @model_class.stubs(:name).returns "my name"
                @handler.expects(:set_response).with { |response, body, status| status == 404 }
                @model_class.stubs(:find).returns(nil)
                @handler.do_find(@request, @response)
            end

            it "should serialize the result in with the appropriate format" do
                @model_instance = stub('model instance')

                @handler.expects(:format_to_use).returns "one"
                @model_instance.expects(:render).with("one").returns "my_rendered_object"
                @model_class.stubs(:find).returns(@model_instance)
                @handler.do_find(@request, @response)
            end
        end

        describe "when searching for model instances" do
            before do
                @handler.stubs(:http_method).returns('GET')
                @handler.stubs(:path).returns('/my_handlers')
                @handler.stubs(:singular?).returns(false)
                @handler.stubs(:plural?).returns(true)
                @handler.stubs(:request_key).returns('key')

                @result1 = mock 'result1'
                @result2 = mock 'results'

                @result = [@result1, @result2]
                @model_class.stubs(:render_multiple).returns "my rendered instances"
                @model_class.stubs(:search).returns(@result)

                @format = stub 'format', :suitable? => true
                Puppet::Network::FormatHandler.stubs(:format).returns @format
            end

            it "should use a common method for determining the request parameters" do
                @handler.stubs(:params).returns(:foo => :baz, :bar => :xyzzy)
                @model_class.expects(:search).with do |key, args|
                    args[:foo] == :baz and args[:bar] == :xyzzy
                end.returns @result
                @handler.do_search(@request, @response)
            end

            it "should use a request key if one is provided" do
                @handler.expects(:request_key).with(@request).returns "foo"
                @model_class.expects(:search).with { |key, args| key == "foo" }.returns @result
                @handler.do_search(@request, @response)
            end

            it "should work with no request key if none is provided" do
                @handler.expects(:request_key).with(@request).returns nil
                @model_class.expects(:search).with { |args| args.is_a?(Hash) }.returns @result
                @handler.do_search(@request, @response)
            end

            it "should use the default status when a model search call succeeds" do
                @model_class.stubs(:search).returns(@result)
                @handler.do_search(@request, @response)
            end

            it "should set the content type to the first format returned by the accept header" do
                @handler.expects(:accept_header).with(@request).returns "one,two"
                @handler.expects(:set_content_type).with(@response, "one")

                @handler.do_search(@request, @response)
            end

            it "should return a list of serialized objects when a model search call succeeds" do
                @handler.expects(:accept_header).with(@request).returns "one,two"

                @model_class.stubs(:search).returns(@result)

                @model_class.expects(:render_multiple).with("one", @result).returns "my rendered instances"

                @handler.expects(:set_response).with { |response, data| data == "my rendered instances" }
                @handler.do_search(@request, @response)
            end

            it "should return a 404 when searching returns an empty array" do
                @model_class.stubs(:name).returns "my name"
                @handler.expects(:set_response).with { |response, body, status| status == 404 }
                @model_class.stubs(:search).returns([])
                @handler.do_search(@request, @response)
            end

            it "should return a 404 when searching returns nil" do
                @model_class.stubs(:name).returns "my name"
                @handler.expects(:set_response).with { |response, body, status| status == 404 }
                @model_class.stubs(:search).returns([])
                @handler.do_search(@request, @response)
            end
        end

        describe "when destroying a model instance" do
            before do
                @handler.stubs(:http_method).returns('DELETE')
                @handler.stubs(:path).returns('/my_handler/key')
                @handler.stubs(:singular?).returns(true)
                @handler.stubs(:request_key).returns('key')

                @result = stub 'result', :render => "the result"
                @model_class.stubs(:destroy).returns @result
            end

            it "should fail to destroy model if key is not specified" do
                @handler.expects(:request_key).returns nil
                lambda { @handler.do_destroy(@request, @response) }.should raise_error(ArgumentError)
            end

            it "should use a common method for determining the request parameters" do
                @handler.stubs(:params).returns(:foo => :baz, :bar => :xyzzy)
                @model_class.expects(:destroy).with do |key, args|
                    args[:foo] == :baz and args[:bar] == :xyzzy
                end
                @handler.do_destroy(@request, @response)
            end

            it "should use the default status code a model destroy call succeeds" do
                @handler.expects(:set_response).with { |response, body, status| status.nil? }
                @handler.do_destroy(@request, @response)
            end

            it "should return a yaml-encoded result when a model destroy call succeeds" do
                @result = stub 'result', :to_yaml => "the result"
                @model_class.expects(:destroy).returns(@result)

                @handler.expects(:set_response).with { |response, body, status| body == "the result" }

                @handler.do_destroy(@request, @response)
            end
        end

        describe "when saving a model instance" do
            before do
                @handler.stubs(:http_method).returns('PUT')
                @handler.stubs(:path).returns('/my_handler/key')
                @handler.stubs(:singular?).returns(true)
                @handler.stubs(:request_key).returns('key')
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

                @handler.do_save(@request, @response)
            end

            it "should fail to save model if data is not specified" do
                @handler.stubs(:body).returns('')

                lambda { @handler.do_save(@request, @response) }.should raise_error(ArgumentError)
            end

            it "should use a common method for determining the request parameters" do
                @handler.stubs(:params).returns(:foo => :baz, :bar => :xyzzy)
                @model_instance.expects(:save).with do |args|
                    args[:foo] == :baz and args[:bar] == :xyzzy
                end
                @handler.do_save(@request, @response)
            end

            it "should use the default status when a model save call succeeds" do
                @handler.expects(:set_response).with { |response, body, status| status.nil? }
                @handler.do_save(@request, @response)
            end

            it "should return the yaml-serialized result when a model save call succeeds" do
                @model_instance.stubs(:save).returns(@model_instance)
                @model_instance.expects(:to_yaml).returns('foo')
                @handler.do_save(@request, @response)
            end

            it "should set the content to yaml" do
                @handler.expects(:set_content_type).with(@response, "yaml")
                @handler.do_save(@request, @response)
            end
        end
    end
end
