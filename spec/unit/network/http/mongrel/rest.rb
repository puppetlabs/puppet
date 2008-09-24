#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../../spec_helper'

require 'puppet/network/http'

describe "Puppet::Network::HTTP::MongrelREST" do
    confine "Mongrel is not available" => Puppet.features.mongrel?
    before do
        require 'puppet/network/http/mongrel/rest'
    end


    it "should include the Puppet::Network::HTTP::Handler module" do
        Puppet::Network::HTTP::MongrelREST.ancestors.should be_include(Puppet::Network::HTTP::Handler)
    end

    describe "when initializing" do
        it "should call the Handler's initialization hook with its provided arguments as the server and handler" do
            Puppet::Network::HTTP::MongrelREST.any_instance.expects(:initialize_for_puppet).with(:server => "my", :handler => "arguments")
            Puppet::Network::HTTP::MongrelREST.new(:server => "my", :handler => "arguments")
        end
    end

    describe "when receiving a request" do
        before do
            @params = {}
            @request = stub('mongrel http request', :params => @params)

            @head = stub('response head')
            @body = stub('response body', :write => true)
            @response = stub('mongrel http response')
            @response.stubs(:start).yields(@head, @body)
            @model_class = stub('indirected model class')
            @mongrel = stub('mongrel http server', :register => true)
            Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@model_class)
            @handler = Puppet::Network::HTTP::MongrelREST.new(:server => @mongrel, :handler => :foo)
        end

        describe "and using the HTTP Handler interface" do
            it "should return the HTTP_ACCEPT parameter as the accept header" do
                @params.expects(:[]).with("HTTP_ACCEPT").returns "myaccept"
                @handler.accept_header(@request).should == "myaccept"
            end

            it "should use the REQUEST_METHOD as the http method" do
                @params.expects(:[]).with(Mongrel::Const::REQUEST_METHOD).returns "mymethod"
                @handler.http_method(@request).should == "mymethod"
            end

            it "should use the first part of the request path as the path" do
                @params.expects(:[]).with(Mongrel::Const::REQUEST_PATH).returns "/foo/bar"
                @handler.path(@request).should == "/foo"
            end

            it "should use the remainder of the request path as the request key" do
                @params.expects(:[]).with(Mongrel::Const::REQUEST_PATH).returns "/foo/bar/baz"
                @handler.request_key(@request).should == "bar/baz"
            end

            it "should return nil as the request key if no second field is present" do
                @params.expects(:[]).with(Mongrel::Const::REQUEST_PATH).returns "/foo"
                @handler.request_key(@request).should be_nil
            end

            it "should return the request body as the body" do
                @request.expects(:body).returns "mybody"
                @handler.body(@request).should == "mybody"
            end

            it "should set the response's content-type header when setting the content type" do
                @header = mock 'header'
                @response.expects(:header).returns @header
                @header.expects(:[]=).with('Content-Type', "mytype")

                @handler.set_content_type(@response, "mytype")
            end

            it "should set the status and write the body when setting the response for a successful request" do
                head = mock 'head'
                body = mock 'body'
                @response.expects(:start).with(200).yields(head, body)

                body.expects(:write).with("mybody")

                @handler.set_response(@response, "mybody", 200)
            end

            it "should set the status and reason and write the body when setting the response for a successful request" do
                head = mock 'head'
                body = mock 'body'
                @response.expects(:start).with(400, false, "mybody").yields(head, body)

                body.expects(:write).with("mybody")

                @handler.set_response(@response, "mybody", 400)
            end
        end

        describe "and determining the request parameters", :shared => true do
            before do
                @request.stubs(:params).returns({})
            end

            it "should include the HTTP request parameters" do
                @request.expects(:params).returns('QUERY_STRING' => 'foo=baz&bar=xyzzy')
                result = @handler.params(@request)
                result["foo"].should == "baz"
                result["bar"].should == "xyzzy"
            end

            it "should pass the client's ip address to model find" do
                @request.stubs(:params).returns("REMOTE_ADDR" => "ipaddress")
                @handler.params(@request)[:ip].should == "ipaddress"
            end

            it "should use the :ssl_client_header to determine the parameter when looking for the certificate" do
                Puppet.settings.stubs(:value).returns "eh"
                Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
                @request.stubs(:params).returns("myheader" => "/CN=host.domain.com")
                @handler.params(@request)
            end

            it "should retrieve the hostname by matching the certificate parameter" do
                Puppet.settings.stubs(:value).returns "eh"
                Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
                @request.stubs(:params).returns("myheader" => "/CN=host.domain.com")
                @handler.params(@request)[:node].should == "host.domain.com"
            end

            it "should use the :ssl_client_header to determine the parameter for checking whether the host certificate is valid" do
                Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
                Puppet.settings.expects(:value).with(:ssl_client_verify_header).returns "myheader"
                @request.stubs(:params).returns("myheader" => "SUCCESS", "certheader" => "/CN=host.domain.com")
                @handler.params(@request)
            end

            it "should consider the host authenticated if the validity parameter contains 'SUCCESS'" do
                Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
                Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
                @request.stubs(:params).returns("myheader" => "SUCCESS", "certheader" => "/CN=host.domain.com")
                @handler.params(@request)[:authenticated].should be_true
            end

            it "should consider the host unauthenticated if the validity parameter does not contain 'SUCCESS'" do
                Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
                Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
                @request.stubs(:params).returns("myheader" => "whatever", "certheader" => "/CN=host.domain.com")
                @handler.params(@request)[:authenticated].should be_false
            end

            it "should consider the host unauthenticated if no certificate information is present" do
                Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
                Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
                @request.stubs(:params).returns("myheader" => nil, "certheader" => "SUCCESS")
                @handler.params(@request)[:authenticated].should be_false
            end

            it "should not pass a node name to model method if no certificate information is present" do
                Puppet.settings.stubs(:value).returns "eh"
                Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
                @request.stubs(:params).returns("myheader" => nil)
                @handler.params(@request).should_not be_include(:node)
            end
        end
    end
end
