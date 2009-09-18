#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/rest'

describe "a REST http call", :shared => true do
    it "should accept a path" do
        lambda { @search.send(@method, *@arguments) }.should_not raise_error(ArgumentError)
    end

    it "should require a path" do
        lambda { @searcher.send(@method) }.should raise_error(ArgumentError)
    end

    it "should return the results of deserializing the response to the request" do
        conn = mock 'connection'
        conn.stubs(:put).returns @response
        conn.stubs(:delete).returns @response
        conn.stubs(:get).returns @response
        Puppet::Network::HttpPool.stubs(:http_instance).returns conn

        @searcher.expects(:deserialize).with(@response).returns "myobject"

        @searcher.send(@method, *@arguments).should == 'myobject'
    end
end

describe Puppet::Indirector::REST do
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = stub('model', :supported_formats => %w{}, :convert_from => nil)
        @instance = stub('model instance', :name= => nil)
        @indirection = stub('indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model)
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @rest_class = Class.new(Puppet::Indirector::REST) do
            def self.to_s
                "This::Is::A::Test::Class"
            end
        end

        @response = stub('mock response', :body => 'result', :code => "200")
        @response.stubs(:[]).with('content-type').returns "text/plain"

        @searcher = @rest_class.new
        @searcher.stubs(:model).returns @model
    end

    it "should include the v1 REST API module" do
        Puppet::Indirector::REST.ancestors.should be_include(Puppet::Network::HTTP::API::V1)
    end

    it "should have a method for specifying what setting a subclass should use to retrieve its server" do
        @rest_class.should respond_to(:use_server_setting)
    end

    it "should use any specified setting to pick the server" do
        @rest_class.expects(:server_setting).returns :servset
        Puppet.settings.expects(:value).with(:servset).returns "myserver"
        @rest_class.server.should == "myserver"
    end

    it "should default to :server for the server setting" do
        @rest_class.expects(:server_setting).returns nil
        Puppet.settings.expects(:value).with(:server).returns "myserver"
        @rest_class.server.should == "myserver"
    end

    it "should have a method for specifying what setting a subclass should use to retrieve its port" do
        @rest_class.should respond_to(:use_port_setting)
    end

    it "should use any specified setting to pick the port" do
        @rest_class.expects(:port_setting).returns :servset
        Puppet.settings.expects(:value).with(:servset).returns "321"
        @rest_class.port.should == 321
    end

    it "should default to :port for the port setting" do
        @rest_class.expects(:port_setting).returns nil
        Puppet.settings.expects(:value).with(:masterport).returns "543"
        @rest_class.port.should == 543
    end

    describe "when deserializing responses" do
        it "should return nil if the response code is 404" do
            response = mock 'response'
            response.expects(:code).returns "404"

            @searcher.deserialize(response).should be_nil
        end

        [300,400,403,405,500,501,502,503,504].each { |rc|
            describe "when the response code is #{rc}" do
                before :each do
                    @model.expects(:convert_from).never

                    @response = mock 'response'
                    @response.stubs(:code).returns rc.to_s
                    @response.stubs(:message).returns "There was a problem (header)"
                end

                it "should fail" do
                    @response.stubs(:body).returns nil
                    lambda { @searcher.deserialize(@response) }.should raise_error(Net::HTTPError)
                end

                it "should take the error message from the body, if present" do
                    @response.stubs(:body).returns "There was a problem (body)"
                    lambda { @searcher.deserialize(@response) }.should raise_error(Net::HTTPError,"Error #{rc} on SERVER: There was a problem (body)")
                end

                it "should take the error message from the response header if the body is empty" do
                    @response.stubs(:body).returns ""
                    lambda { @searcher.deserialize(@response) }.should raise_error(Net::HTTPError,"Error #{rc} on SERVER: There was a problem (header)")
                end

                it "should take the error message from the response header if the body is absent" do
                    @response.stubs(:body).returns nil
                    lambda { @searcher.deserialize(@response) }.should raise_error(Net::HTTPError,"Error #{rc} on SERVER: There was a problem (header)")
                end
            end
        }    

        it "should return the results of converting from the format specified by the content-type header if the response code is in the 200s" do
            @model.expects(:convert_from).with("myformat", "mydata").returns "myobject"

            response = mock 'response'
            response.stubs(:[]).with("content-type").returns "myformat"
            response.stubs(:body).returns "mydata"
            response.stubs(:code).returns "200"

            @searcher.deserialize(response).should == "myobject"
        end

        it "should convert and return multiple instances if the return code is in the 200s and 'multiple' is specified" do
            @model.expects(:convert_from_multiple).with("myformat", "mydata").returns "myobjects"

            response = mock 'response'
            response.stubs(:[]).with("content-type").returns "myformat"
            response.stubs(:body).returns "mydata"
            response.stubs(:code).returns "200"

            @searcher.deserialize(response, true).should == "myobjects"
        end

        it "should strip the content-type header to keep only the mime-type" do
            @model.expects(:convert_from).with("text/plain", "mydata").returns "myobject"

            response = mock 'response'
            response.stubs(:[]).with("content-type").returns "text/plain; charset=utf-8"
            response.stubs(:body).returns "mydata"
            response.stubs(:code).returns "200"

            @searcher.deserialize(response)
        end
    end

    describe "when creating an HTTP client" do
        before do
            Puppet.settings.stubs(:value).returns("rest_testing")
        end

        it "should use the class's server and port if the indirection request provides neither" do
            @request = stub 'request', :key => "foo", :server => nil, :port => nil
            @searcher.class.expects(:port).returns 321
            @searcher.class.expects(:server).returns "myserver"
            Puppet::Network::HttpPool.expects(:http_instance).with("myserver", 321).returns "myconn"
            @searcher.network(@request).should == "myconn"
        end

        it "should use the server from the indirection request if one is present" do
            @request = stub 'request', :key => "foo", :server => "myserver", :port => nil
            @searcher.class.stubs(:port).returns 321
            Puppet::Network::HttpPool.expects(:http_instance).with("myserver", 321).returns "myconn"
            @searcher.network(@request).should == "myconn"
        end

        it "should use the port from the indirection request if one is present" do
            @request = stub 'request', :key => "foo", :server => nil, :port => 321
            @searcher.class.stubs(:server).returns "myserver"
            Puppet::Network::HttpPool.expects(:http_instance).with("myserver", 321).returns "myconn"
            @searcher.network(@request).should == "myconn"
        end
    end

    describe "when doing a find" do
        before :each do
            @connection = stub('mock http connection', :get => @response)
            @searcher.stubs(:network).returns(@connection)    # neuter the network connection

            # Use a key with spaces, so we can test escaping
            @request = Puppet::Indirector::Request.new(:foo, :find, "foo bar")
        end

        it "should call the GET http method on a network connection" do
            @searcher.expects(:network).returns @connection
            @connection.expects(:get).returns @response
            @searcher.find(@request)
        end

        it "should deserialize and return the http response" do
            @connection.expects(:get).returns @response

            instance = stub 'object', :name= => nil
            @searcher.expects(:deserialize).with(@response).returns instance

            @searcher.find(@request).should == instance
        end

        it "should use the URI generated by the Handler module" do
            @searcher.expects(:indirection2uri).with(@request).returns "/my/uri"
            @connection.expects(:get).with { |path, args| path == "/my/uri" }.returns(@response)
            @searcher.find(@request)
        end

        it "should provide an Accept header containing the list of supported formats joined with commas" do
            @connection.expects(:get).with { |path, args| args["Accept"] == "supported, formats" }.returns(@response)

            @searcher.model.expects(:supported_formats).returns %w{supported formats}
            @searcher.find(@request)
        end

        it "should deserialize and return the network response" do
            @searcher.expects(:deserialize).with(@response).returns @instance
            @searcher.find(@request).should equal(@instance)
        end

        it "should set the name of the resulting instance to the asked-for name" do
            @searcher.expects(:deserialize).with(@response).returns @instance
            @instance.expects(:name=).with "foo bar"
            @searcher.find(@request)
        end

        it "should generate an error when result data deserializes fails" do
            @searcher.expects(:deserialize).raises(ArgumentError)
            lambda { @searcher.find(@request) }.should raise_error(ArgumentError)
        end
    end

    describe "when doing a search" do
        before :each do
            @connection = stub('mock http connection', :get => @response)
            @searcher.stubs(:network).returns(@connection)    # neuter the network connection

            @model.stubs(:convert_from_multiple)

            @request = Puppet::Indirector::Request.new(:foo, :search, "foo bar")
        end

        it "should call the GET http method on a network connection" do
            @searcher.expects(:network).returns @connection
            @connection.expects(:get).returns @response
            @searcher.search(@request)
        end

        it "should deserialize as multiple instances and return the http response" do
            @connection.expects(:get).returns @response
            @searcher.expects(:deserialize).with(@response, true).returns "myobject"

            @searcher.search(@request).should == 'myobject'
        end

        it "should use the URI generated by the Handler module" do
            @searcher.expects(:indirection2uri).with(@request).returns "/mys/uri"
            @connection.expects(:get).with { |path, args| path == "/mys/uri" }.returns(@response)
            @searcher.search(@request)
        end

        it "should provide an Accept header containing the list of supported formats joined with commas" do
            @connection.expects(:get).with { |path, args| args["Accept"] == "supported, formats" }.returns(@response)

            @searcher.model.expects(:supported_formats).returns %w{supported formats}
            @searcher.search(@request)
        end

        it "should return an empty array if serialization returns nil" do
            @model.stubs(:convert_from_multiple).returns nil

            @searcher.search(@request).should == []
        end

        it "should generate an error when result data deserializes fails" do
            @searcher.expects(:deserialize).raises(ArgumentError)
            lambda { @searcher.search(@request) }.should raise_error(ArgumentError)
        end
    end

    describe "when doing a destroy" do
        before :each do
            @connection = stub('mock http connection', :delete => @response)
            @searcher.stubs(:network).returns(@connection)    # neuter the network connection

            @request = Puppet::Indirector::Request.new(:foo, :destroy, "foo bar")
        end

        it "should call the DELETE http method on a network connection" do
            @searcher.expects(:network).returns @connection
            @connection.expects(:delete).returns @response
            @searcher.destroy(@request)
        end

        it "should fail if any options are provided, since DELETE apparently does not support query options" do
            @request.stubs(:options).returns(:one => "two", :three => "four")

            lambda { @searcher.destroy(@request) }.should raise_error(ArgumentError)
        end

        it "should deserialize and return the http response" do
            @connection.expects(:delete).returns @response
            @searcher.expects(:deserialize).with(@response).returns "myobject"

            @searcher.destroy(@request).should == 'myobject'
        end

        it "should use the URI generated by the Handler module" do
            @searcher.expects(:indirection2uri).with(@request).returns "/my/uri"
            @connection.expects(:delete).with { |path, args| path == "/my/uri" }.returns(@response)
            @searcher.destroy(@request)
        end

        it "should not include the query string" do
            @connection.stubs(:delete).returns @response
            @searcher.destroy(@request)
        end

        it "should provide an Accept header containing the list of supported formats joined with commas" do
            @connection.expects(:delete).with { |path, args| args["Accept"] == "supported, formats" }.returns(@response)

            @searcher.model.expects(:supported_formats).returns %w{supported formats}
            @searcher.destroy(@request)
        end

        it "should deserialize and return the network response" do
            @searcher.expects(:deserialize).with(@response).returns @instance
            @searcher.destroy(@request).should equal(@instance)
        end

        it "should generate an error when result data deserializes fails" do
            @searcher.expects(:deserialize).raises(ArgumentError)
            lambda { @searcher.destroy(@request) }.should raise_error(ArgumentError)
        end
    end

    describe "when doing a save" do
        before :each do
            @connection = stub('mock http connection', :put => @response)
            @searcher.stubs(:network).returns(@connection)    # neuter the network connection

            @instance = stub 'instance', :render => "mydata", :mime => "mime"
            @request = Puppet::Indirector::Request.new(:foo, :save, "foo bar")
            @request.instance = @instance
        end

        it "should call the PUT http method on a network connection" do
            @searcher.expects(:network).returns @connection
            @connection.expects(:put).returns @response
            @searcher.save(@request)
        end

        it "should fail if any options are provided, since DELETE apparently does not support query options" do
            @request.stubs(:options).returns(:one => "two", :three => "four")

            lambda { @searcher.save(@request) }.should raise_error(ArgumentError)
        end

        it "should use the URI generated by the Handler module" do
            @searcher.expects(:indirection2uri).with(@request).returns "/my/uri"
            @connection.expects(:put).with { |path, args| path == "/my/uri" }.returns(@response)
            @searcher.save(@request)
        end

        it "should serialize the instance using the default format and pass the result as the body of the request" do
            @instance.expects(:render).returns "serial_instance"
            @connection.expects(:put).with { |path, data, args| data == "serial_instance" }.returns @response

            @searcher.save(@request)
        end

        it "should deserialize and return the http response" do
            @connection.expects(:put).returns @response
            @searcher.expects(:deserialize).with(@response).returns "myobject"

            @searcher.save(@request).should == 'myobject'
        end

        it "should provide an Accept header containing the list of supported formats joined with commas" do
            @connection.expects(:put).with { |path, data, args| args["Accept"] == "supported, formats" }.returns(@response)

            @searcher.model.expects(:supported_formats).returns %w{supported formats}
            @searcher.save(@request)
        end

        it "should provide a Content-Type header containing the mime-type of the sent object" do
            @connection.expects(:put).with { |path, data, args| args['Content-Type'] == "mime" }.returns(@response)

            @instance.expects(:mime).returns "mime"
            @searcher.save(@request)
        end

        it "should deserialize and return the network response" do
            @searcher.expects(:deserialize).with(@response).returns @instance
            @searcher.save(@request).should equal(@instance)
        end

        it "should generate an error when result data deserializes fails" do
            @searcher.expects(:deserialize).raises(ArgumentError)
            lambda { @searcher.save(@request) }.should raise_error(ArgumentError)
        end
    end
end
