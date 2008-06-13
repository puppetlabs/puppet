#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../../spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::MongrelREST, "when initializing" do
    confine "Mongrel is not available" => Puppet.features.mongrel?

    before do
        @mock_mongrel = mock('Mongrel server')
        @mock_mongrel.stubs(:register)
        @mock_model = mock('indirected model')
        Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@mock_model)
        @params = { :server => @mock_mongrel, :handler => :foo }
    end

    it "should require access to a Mongrel server" do
        Proc.new { Puppet::Network::HTTP::MongrelREST.new(@params.delete_if {|k,v| :server == k })}.should raise_error(ArgumentError)
    end

    it "should require an indirection name" do
        Proc.new { Puppet::Network::HTTP::MongrelREST.new(@params.delete_if {|k,v| :handler == k })}.should raise_error(ArgumentError)        
    end

    it "should look up the indirection model from the indirection name" do
        Puppet::Indirector::Indirection.expects(:model).with(:foo).returns(@mock_model)
        Puppet::Network::HTTP::MongrelREST.new(@params)
    end

    it "should fail if the indirection is not known" do
        Puppet::Indirector::Indirection.expects(:model).with(:foo).returns(nil)
        Proc.new { Puppet::Network::HTTP::MongrelREST.new(@params) }.should raise_error(ArgumentError)
    end
end

describe Puppet::Network::HTTP::MongrelREST, "when receiving a request" do
    confine "Mongrel is not available" => Puppet.features.mongrel?

    before do
        @mock_request = stub('mongrel http request')
        @mock_head = stub('response head')
        @mock_body = stub('response body', :write => true)
        @mock_response = stub('mongrel http response')
        @mock_response.stubs(:start).yields(@mock_head, @mock_body)
        @mock_model_class = stub('indirected model class')
        @mock_mongrel = stub('mongrel http server', :register => true)
        Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@mock_model_class)
        @handler = Puppet::Network::HTTP::MongrelREST.new(:server => @mock_mongrel, :handler => :foo)
    end

    def setup_find_request(params = {})
        @mock_request.stubs(:params).returns({  Mongrel::Const::REQUEST_METHOD => 'GET', 
                                                Mongrel::Const::REQUEST_PATH => '/foo/key',
                                                'QUERY_STRING' => ''}.merge(params))
        @mock_model_class.stubs(:find)
    end

    def setup_search_request(params = {})
        @mock_request.stubs(:params).returns({  Mongrel::Const::REQUEST_METHOD => 'GET', 
                                                Mongrel::Const::REQUEST_PATH => '/foos',
                                                'QUERY_STRING' => '' }.merge(params))
        @mock_model_class.stubs(:search).returns([])        
    end

    def setup_destroy_request(params = {})
        @mock_request.stubs(:params).returns({  Mongrel::Const::REQUEST_METHOD => 'DELETE', 
                                                Mongrel::Const::REQUEST_PATH => '/foo/key',
                                                'QUERY_STRING' => '' }.merge(params))
        @mock_model_class.stubs(:destroy)
    end

    def setup_save_request(params = {})
        @mock_request.stubs(:params).returns({  Mongrel::Const::REQUEST_METHOD => 'PUT', 
                                                Mongrel::Const::REQUEST_PATH => '/foo',
                                                'QUERY_STRING' => '' }.merge(params))
        @mock_request.stubs(:body).returns('this is a fake request body')
        @mock_model_instance = stub('indirected model instance', :save => true)
        @mock_model_class.stubs(:from_yaml).returns(@mock_model_instance)
    end

    def setup_bad_request
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'POST', Mongrel::Const::REQUEST_PATH => '/foos'})        
    end

    it "should call the model find method if the request represents a singular HTTP GET" do
        setup_find_request
        @mock_model_class.expects(:find).with { |key, args| key == 'key' }
        @handler.process(@mock_request, @mock_response)
    end

    it "should call the model search method if the request represents a plural HTTP GET" do
        setup_search_request
        @mock_model_class.expects(:search).returns([])
        @handler.process(@mock_request, @mock_response)
    end

    it "should call the model destroy method if the request represents an HTTP DELETE" do
        setup_destroy_request
        @mock_model_class.expects(:destroy).with { |key, args| key == 'key' }
        @handler.process(@mock_request, @mock_response)
    end

    it "should call the model save method if the request represents an HTTP PUT" do
        setup_save_request
        @mock_model_instance.expects(:save)
        @handler.process(@mock_request, @mock_response)
    end

    it "should fail if the HTTP method isn't supported" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'POST', Mongrel::Const::REQUEST_PATH => '/foo'})
        @mock_response.expects(:start).with(404)
        @handler.process(@mock_request, @mock_response)
    end

    it "should fail if the request's pluralization is wrong" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'DELETE', Mongrel::Const::REQUEST_PATH => '/foos/key'})
        @mock_response.expects(:start).with(404)
        @handler.process(@mock_request, @mock_response)

        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'PUT', Mongrel::Const::REQUEST_PATH => '/foos/key'})
        @mock_response.expects(:start).with(404)
        @handler.process(@mock_request, @mock_response)
    end

    it "should fail if the request is for an unknown path" do
        @mock_request.stubs(:params).returns({  Mongrel::Const::REQUEST_METHOD => 'GET', 
                                                Mongrel::Const::REQUEST_PATH => '/bar/key',
                                                'QUERY_STRING' => '' })
        @mock_response.expects(:start).with(404)
        @handler.process(@mock_request, @mock_response)
    end

    describe "and determining the request parameters", :shared => true do
        before do
            @mock_request.stubs(:params).returns({})
        end

        it "should include the HTTP request parameters" do
            @mock_request.expects(:params).returns('QUERY_STRING' => 'foo=baz&bar=xyzzy')
            result = @handler.params(@mock_request)
            result["foo"].should == "baz"
            result["bar"].should == "xyzzy"
        end

        it "should pass the client's ip address to model find" do
            @mock_request.stubs(:params).returns("REMOTE_ADDR" => "ipaddress")
            @handler.params(@mock_request)[:ip].should == "ipaddress"
        end

        it "should use the :ssl_client_header to determine the parameter when looking for the certificate" do
            Puppet.settings.stubs(:value).returns "eh"
            Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
            @mock_request.stubs(:params).returns("myheader" => "/CN=host.domain.com")
            @handler.params(@mock_request)
        end

        it "should retrieve the hostname by matching the certificate parameter" do
            Puppet.settings.stubs(:value).returns "eh"
            Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
            @mock_request.stubs(:params).returns("myheader" => "/CN=host.domain.com")
            @handler.params(@mock_request)[:node].should == "host.domain.com"
        end

        it "should use the :ssl_client_header to determine the parameter for checking whether the host certificate is valid" do
            Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
            Puppet.settings.expects(:value).with(:ssl_client_verify_header).returns "myheader"
            @mock_request.stubs(:params).returns("myheader" => "SUCCESS", "certheader" => "/CN=host.domain.com")
            @handler.params(@mock_request)
        end

        it "should consider the host authenticated if the validity parameter contains 'SUCCESS'" do
            Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
            Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
            @mock_request.stubs(:params).returns("myheader" => "SUCCESS", "certheader" => "/CN=host.domain.com")
            @handler.params(@mock_request)[:authenticated].should be_true
        end

        it "should consider the host unauthenticated if the validity parameter does not contain 'SUCCESS'" do
            Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
            Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
            @mock_request.stubs(:params).returns("myheader" => "whatever", "certheader" => "/CN=host.domain.com")
            @handler.params(@mock_request)[:authenticated].should be_false
        end

        it "should consider the host unauthenticated if no certificate information is present" do
            Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
            Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
            @mock_request.stubs(:params).returns("myheader" => nil, "certheader" => "SUCCESS")
            @handler.params(@mock_request)[:authenticated].should be_false
        end

        it "should not pass a node name to model method if no certificate information is present" do
            Puppet.settings.stubs(:value).returns "eh"
            Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
            @mock_request.stubs(:params).returns("myheader" => nil)
            @handler.params(@mock_request).should_not be_include(:node)
        end
    end

    describe "when finding a model instance" do |variable|
        it "should fail to find model if key is not specified" do
            @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'GET', Mongrel::Const::REQUEST_PATH => '/foo'})
            @mock_response.expects(:start).with(404)
            @handler.process(@mock_request, @mock_response)
        end

        it "should use a common method for determining the request parameters" do
            setup_find_request('QUERY_STRING' => 'foo=baz&bar=xyzzy')
            @handler.expects(:params).returns(:foo => :baz, :bar => :xyzzy)
            @mock_model_class.expects(:find).with do |key, args|
                args[:foo] == :baz and args[:bar] == :xyzzy
            end
            @handler.process(@mock_request, @mock_response)
        end

        it "should generate a 200 response when a model find call succeeds" do
            setup_find_request
            @mock_response.expects(:start).with(200)
            @handler.process(@mock_request, @mock_response)
        end

        it "should return a serialized object when a model find call succeeds" do
            setup_find_request
            @mock_model_instance = stub('model instance')
            @mock_model_instance.expects(:to_yaml)
            @mock_model_class.stubs(:find).returns(@mock_model_instance)
            @handler.process(@mock_request, @mock_response)                  
        end

        it "should serialize a controller exception when an exception is thrown by find" do
           setup_find_request
           @mock_model_class.expects(:find).raises(ArgumentError) 
           @mock_response.expects(:start).with(404)
           @handler.process(@mock_request, @mock_response)        
        end
    end

    describe "when destroying a model instance" do |variable|
        it "should fail to destroy model if key is not specified" do
            @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'DELETE', Mongrel::Const::REQUEST_PATH => '/foo'})
            @mock_response.expects(:start).with(404)
            @handler.process(@mock_request, @mock_response)
        end

        it "should use a common method for determining the request parameters" do
            setup_destroy_request('QUERY_STRING' => 'foo=baz&bar=xyzzy')
            @handler.expects(:params).returns(:foo => :baz, :bar => :xyzzy)
            @mock_model_class.expects(:destroy).with do |key, args|
                args[:foo] == :baz and args[:bar] == :xyzzy
            end
            @handler.process(@mock_request, @mock_response)
        end

        it "should pass HTTP request parameters to model destroy" do
            setup_destroy_request('QUERY_STRING' => 'foo=baz&bar=xyzzy')
            @mock_model_class.expects(:destroy).with do |key, args|
                key == 'key' and args['foo'] == 'baz' and args['bar'] == 'xyzzy'
            end
            @handler.process(@mock_request, @mock_response)
        end

        it "should generate a 200 response when a model destroy call succeeds" do
            setup_destroy_request
            @mock_response.expects(:start).with(200)
            @handler.process(@mock_request, @mock_response)
        end

        it "should return a serialized success result when a model destroy call succeeds" do
            setup_destroy_request
            @mock_model_class.stubs(:destroy).returns(true)
            @mock_body.expects(:write).with("--- true\n")
            @handler.process(@mock_request, @mock_response)
        end

        it "should serialize a controller exception when an exception is thrown by destroy" do
            setup_destroy_request
            @mock_model_class.expects(:destroy).raises(ArgumentError) 
            @mock_response.expects(:start).with(404)
            @handler.process(@mock_request, @mock_response)                 
        end
    end

    describe "when saving a model instance" do |variable|    
        it "should fail to save model if data is not specified" do
            @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'PUT', Mongrel::Const::REQUEST_PATH => '/foo'})
            @mock_request.stubs(:body).returns('')
            @mock_response.expects(:start).with(404)
            @handler.process(@mock_request, @mock_response)
        end

        it "should use a common method for determining the request parameters" do
            setup_save_request('QUERY_STRING' => 'foo=baz&bar=xyzzy')
            @handler.expects(:params).returns(:foo => :baz, :bar => :xyzzy)
            @mock_model_instance.expects(:save).with do |args|
                args[:foo] == :baz and args[:bar] == :xyzzy
            end
            @handler.process(@mock_request, @mock_response)
        end

        it "should generate a 200 response when a model save call succeeds" do
            setup_save_request
            @mock_response.expects(:start).with(200)
            @handler.process(@mock_request, @mock_response)
        end

        it "should return a serialized object when a model save call succeeds" do
            setup_save_request
            @mock_model_instance.stubs(:save).returns(@mock_model_instance)
            @mock_model_instance.expects(:to_yaml).returns('foo')
            @handler.process(@mock_request, @mock_response)        
        end

        it "should serialize a controller exception when an exception is thrown by save" do
            setup_save_request
            @mock_model_instance.expects(:save).raises(ArgumentError) 
            @mock_response.expects(:start).with(404)
            @handler.process(@mock_request, @mock_response)                         
        end
    end

    describe "when searching for model instances" do |variable|
        it "should use a common method for determining the request parameters" do
            setup_search_request('QUERY_STRING' => 'foo=baz&bar=xyzzy')
            @handler.expects(:params).returns(:foo => :baz, :bar => :xyzzy)
            @mock_model_class.expects(:search).with do |args|
                args[:foo] == :baz and args[:bar] == :xyzzy
            end
            @handler.process(@mock_request, @mock_response)
        end

        it "should pass HTTP request parameters to model search" do
            setup_search_request('QUERY_STRING' => 'foo=baz&bar=xyzzy')
            @mock_model_class.expects(:search).with do |args|
                args['foo'] == 'baz' and args['bar'] == 'xyzzy'
            end.returns([])
            @handler.process(@mock_request, @mock_response)
        end      

        it "should generate a 200 response when a model search call succeeds" do
            setup_search_request
            @mock_response.expects(:start).with(200)
            @handler.process(@mock_request, @mock_response)
        end

        it "should return a list of serialized objects when a model search call succeeds" do
            setup_search_request
            mock_matches = [1..5].collect {|i| mock("model instance #{i}", :to_yaml => "model instance #{i}") }
            @mock_model_class.stubs(:search).returns(mock_matches)
            @handler.process(@mock_request, @mock_response)                          
        end

        it "should serialize a controller exception when an exception is thrown by search" do
            setup_search_request
            @mock_model_class.expects(:search).raises(ArgumentError) 
            @mock_response.expects(:start).with(404)
            @handler.process(@mock_request, @mock_response)                
        end
    end    

    it "should serialize a controller exception if the request fails" do
        setup_bad_request     
        @mock_response.expects(:start).with(404)
        @handler.process(@mock_request, @mock_response)        
    end
end
