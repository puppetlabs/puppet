#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../../spec_helper'
require 'puppet/network/http'
require 'puppet/network/http/webrick/rest'

describe Puppet::Network::HTTP::WEBrickREST do
    it "should include the Puppet::Network::HTTP::Handler module" do
        Puppet::Network::HTTP::WEBrickREST.ancestors.should be_include(Puppet::Network::HTTP::Handler)
    end

    describe "when initializing" do
        it "should call the Handler's initialization hook with its provided arguments as the server and handler" do
            Puppet::Network::HTTP::WEBrickREST.any_instance.expects(:initialize_for_puppet).with(:server => "my", :handler => "arguments")
            Puppet::Network::HTTP::WEBrickREST.new("my", "arguments")
        end
    end

    describe "when receiving a request" do
        before do
            @request     = stub('webrick http request', :query => {}, :peeraddr => %w{eh boo host ip}, :client_cert => nil)
            @response    = stub('webrick http response', :status= => true, :body= => true)
            @model_class = stub('indirected model class')
            @webrick     = stub('webrick http server', :mount => true, :[] => {})
            Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@model_class)
            @handler = Puppet::Network::HTTP::WEBrickREST.new(@webrick, :foo)
        end

        it "should delegate its :service method to its :process method" do
            @handler.expects(:process).with(@request, @response).returns "stuff"
            @handler.service(@request, @response).should == "stuff"
        end

        describe "when using the Handler interface" do
            it "should use the 'accept' request parameter as the Accept header" do
                @request.expects(:[]).with("accept").returns "foobar"
                @handler.accept_header(@request).should == "foobar"
            end

            it "should use the request method as the http method" do
                @request.expects(:request_method).returns "FOO"
                @handler.http_method(@request).should == "FOO"
            end

            it "should return the first argument of the request path as the path" do
                @request.expects(:path).returns "/foo/bar"
                @handler.path(@request).should == "/foo"
            end

            it "should return the remainder of the path as the request key" do
                @request.expects(:path).returns "/foo/bar/baz"
                @handler.request_key(@request).should == "bar/baz"
            end

            it "should return nil as the request key if there is no second field" do
                @request.expects(:path).returns "/foo"
                @handler.request_key(@request).should be_nil
            end

            it "should return the request body as the body" do
                @request.expects(:body).returns "my body"
                @handler.body(@request).should == "my body"
            end

            it "should set the response's 'content-type' header when setting the content type" do
                @response.expects(:[]=).with("content-type", "text/html")
                @handler.set_content_type(@response, "text/html")
            end

            it "should set the status and body on the response when setting the response for a successful query" do
                @response.expects(:status=).with 200
                @response.expects(:body=).with "mybody"

                @handler.set_response(@response, "mybody", 200)
            end

            it "should set the status and message on the response when setting the response for a failed query" do
                @response.expects(:status=).with 400
                @response.expects(:reason_phrase=).with "mybody"

                @handler.set_response(@response, "mybody", 400)
            end
        end

        describe "and determining the request parameters" do
            it "should include the HTTP request parameters" do
                @request.stubs(:query).returns(:foo => :baz, :bar => :xyzzy)
                result = @handler.params(@request)
                result[:foo].should == :baz
                result[:bar].should == :xyzzy
            end

            it "should pass the client's ip address to model find" do
                @request.stubs(:peeraddr).returns(%w{noidea dunno hostname ipaddress})
                @handler.params(@request)[:ip].should == "ipaddress"
            end

            it "should set 'authenticated' to true if a certificate is present" do
                cert = stub 'cert', :subject => [%w{CN host.domain.com}]
                @request.stubs(:client_cert).returns cert
                @handler.params(@request)[:authenticated].should be_true
            end

            it "should set 'authenticated' to false if no certificate is present" do
                @request.stubs(:client_cert).returns nil
                @handler.params(@request)[:authenticated].should be_false
            end

            it "should pass the client's certificate name to model method if a certificate is present" do
                cert = stub 'cert', :subject => [%w{CN host.domain.com}]
                @request.stubs(:client_cert).returns cert
                @handler.params(@request)[:node].should == "host.domain.com"
            end

            it "should not pass a node name to model method if no certificate is present" do
                @request.stubs(:client_cert).returns nil
                @handler.params(@request).should_not be_include(:node)
            end
        end
    end
end
