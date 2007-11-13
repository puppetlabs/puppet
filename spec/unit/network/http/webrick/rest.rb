#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../../spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::WEBrickREST, "when initializing" do
    before do
        @mock_webrick = stub('WEBrick server', :mount => true)
        @mock_model = mock('indirected model')
        Puppet::Indirector::Indirection.stubs(:model).returns(@mock_model)
        @params = { :server => @mock_webrick, :handler => :foo }
    end
    
    it "should require access to a WEBrick server" do
        Proc.new { Puppet::Network::HTTP::WEBrickREST.new(@params.delete_if {|k,v| :server == k })}.should raise_error(ArgumentError)
    end
    
    it "should require an indirection name" do
        Proc.new { Puppet::Network::HTTP::WEBrickREST.new(@params.delete_if {|k,v| :handler == k })}.should raise_error(ArgumentError)        
    end
    
    it "should look up the indirection model from the indirection name" do
        Puppet::Indirector::Indirection.expects(:model).returns(@mock_model)
        Puppet::Network::HTTP::WEBrickREST.new(@params)
    end
    
    it "should fail if the indirection is not known" do
        Puppet::Indirector::Indirection.expects(:model).returns(nil)
        Proc.new { Puppet::Network::HTTP::WEBrickREST.new(@params) }.should raise_error(ArgumentError)
    end
    
    it "should register itself with the WEBrick server for the singular HTTP methods" do
        @mock_webrick.expects(:mount).with do |*args|
            args.first == '/foo' and args.last.is_a?(Puppet::Network::HTTP::WEBrickREST)
        end
        Puppet::Network::HTTP::WEBrickREST.new(@params)
    end

    it "should register itself with the WEBrick server for the plural GET method" do
        @mock_webrick.expects(:mount).with do |*args|
            args.first == '/foos' and args.last.is_a?(Puppet::Network::HTTP::WEBrickREST)
        end
        Puppet::Network::HTTP::WEBrickREST.new(@params)
    end
end

describe Puppet::Network::HTTP::WEBrickREST, "when receiving a request" do
    before do
        @mock_request     = stub('webrick http request', :query => {})
        @mock_response    = stub('webrick http response', :status= => true, :body= => true)
        @mock_model_class = stub('indirected model class')
        @mock_webrick     = stub('mongrel http server', :mount => true)
        Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@mock_model_class)
        @handler = Puppet::Network::HTTP::WEBrickREST.new(:server => @mock_webrick, :handler => :foo)
    end

    def setup_find_request
        @mock_request.stubs(:request_method).returns('GET')
        @mock_request.stubs(:path).returns('/foo/key')
        @mock_model_class.stubs(:find)
    end
    
    def setup_search_request
        @mock_request.stubs(:request_method).returns('GET')
        @mock_request.stubs(:path).returns('/foos')
        @mock_model_class.stubs(:search).returns([])
    end
    
    def setup_destroy_request
        @mock_request.stubs(:request_method).returns('DELETE')
        @mock_request.stubs(:path).returns('/foo/key')
        @mock_model_class.stubs(:destroy)
    end
    
    def setup_save_request
        @mock_request.stubs(:request_method).returns('PUT')
        @mock_request.stubs(:path).returns('/foo')
        @mock_request.stubs(:body).returns('This is a fake request body')
        @mock_model_instance = stub('indirected model instance', :save => true)
        @mock_model_class.stubs(:new).returns(@mock_model_instance)
    end
    
    def setup_bad_request
        @mock_request.stubs(:request_method).returns('POST')
        @mock_request.stubs(:path).returns('/foos')
    end
    
    it "should call the model find method if the request represents a singular HTTP GET" do
        setup_find_request
        @mock_model_class.expects(:find).with('key', {})
        @handler.service(@mock_request, @mock_response)
    end

    it "should call the model search method if the request represents a plural HTTP GET" do
        setup_search_request
        @mock_model_class.expects(:search).returns([])
        @handler.service(@mock_request, @mock_response)
    end
    
    it "should call the model destroy method if the request represents an HTTP DELETE" do
        setup_destroy_request
        @mock_model_class.expects(:destroy).with('key', {})
        @handler.service(@mock_request, @mock_response)
    end

    it "should call the model save method if the request represents an HTTP PUT" do
        setup_save_request
        @mock_model_instance.expects(:save).with(:data => 'This is a fake request body')
        @mock_model_class.expects(:new).returns(@mock_model_instance)
        @handler.service(@mock_request, @mock_response)
    end
    
    it "should fail if the HTTP method isn't supported" do
        @mock_request.stubs(:request_method).returns('POST')
        @mock_request.stubs(:path).returns('/foo')
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)            
    end
    
    it "should fail if the request's pluralization is wrong" do
        @mock_request.stubs(:request_method).returns('DELETE')
        @mock_request.stubs(:path).returns('/foos/key')
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)            
        
        @mock_request.stubs(:request_method).returns('PUT')
        @mock_request.stubs(:path).returns('/foos/key')
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)            
    end

    it "should fail if the request is for an unknown path" do
        @mock_request.stubs(:request_method).returns('GET')
        @mock_request.stubs(:path).returns('/bar/key')
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)            
    end

    it "should fail to find model if key is not specified" do
        @mock_request.stubs(:request_method).returns('GET')
        @mock_request.stubs(:path).returns('/foo')
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)            
    end
    
    it "should fail to destroy model if key is not specified" do
        @mock_request.stubs(:request_method).returns('DELETE')
        @mock_request.stubs(:path).returns('/foo')
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)            
    end
    
    it "should fail to save model if data is not specified" do
        @mock_request.stubs(:request_method).returns('PUT')
        @mock_request.stubs(:path).returns('/foo')
        @mock_request.stubs(:body).returns('')
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)            
    end

    it "should pass HTTP request parameters to model find" do
        setup_find_request
        @mock_request.stubs(:query).returns(:foo => :baz, :bar => :xyzzy)
        @mock_model_class.expects(:find).with do |key, args|
            key == 'key' and args[:foo] == :baz and args[:bar] == :xyzzy
        end
        @handler.service(@mock_request, @mock_response)
    end
    
    it "should pass HTTP request parameters to model search" do
        setup_search_request
        @mock_request.stubs(:query).returns(:foo => :baz, :bar => :xyzzy)
        @mock_model_class.expects(:search).with do |args|
            args[:foo] == :baz and args[:bar] == :xyzzy
        end.returns([])
        @handler.service(@mock_request, @mock_response)
    end
    
    it "should pass HTTP request parameters to model destroy" do
        setup_destroy_request
        @mock_request.stubs(:query).returns(:foo => :baz, :bar => :xyzzy)
        @mock_model_class.expects(:destroy).with do |key, args|
            key == 'key' and args[:foo] == :baz and args[:bar] == :xyzzy
        end
        @handler.service(@mock_request, @mock_response)
    end
    
    it "should pass HTTP request parameters to model save" do
        setup_save_request
        @mock_request.stubs(:query).returns(:foo => :baz, :bar => :xyzzy)
        @mock_model_instance.expects(:save).with do |args|
            args[:data] == 'This is a fake request body' and args[:foo] == :baz and args[:bar] == :xyzzy
        end
        @handler.service(@mock_request, @mock_response)
    end

    it "should generate a 200 response when a model find call succeeds" do
        setup_find_request
        @mock_response.expects(:status=).with(200)
        @handler.process(@mock_request, @mock_response)      
    end

    it "should generate a 200 response when a model search call succeeds" do
        setup_search_request
        @mock_response.expects(:status=).with(200)
        @handler.process(@mock_request, @mock_response)      
    end

    it "should generate a 200 response when a model destroy call succeeds" do
        setup_destroy_request
        @mock_response.expects(:status=).with(200)
        @handler.process(@mock_request, @mock_response)      
    end
    
    it "should generate a 200 response when a model save call succeeds" do
        setup_save_request
        @mock_response.expects(:status=).with(200)
        @handler.process(@mock_request, @mock_response)            
    end

    it "should return a serialized object when a model find call succeeds" do
        setup_find_request
        @mock_model_instance = stub('model instance')
        @mock_model_instance.expects(:to_yaml)
        @mock_model_class.stubs(:find).returns(@mock_model_instance)
        @handler.process(@mock_request, @mock_response)                  
    end
    
    it "should return a list of serialized objects when a model search call succeeds" do
        setup_search_request
        mock_matches = [1..5].collect {|i| mock("model instance #{i}", :to_yaml => "model instance #{i}") }
        @mock_model_class.stubs(:search).returns(mock_matches)
        @handler.process(@mock_request, @mock_response)                          
    end
    
    it "should return a serialized success result when a model destroy call succeeds" do
        setup_destroy_request
        @mock_model_class.stubs(:destroy).returns(true)
        @mock_response.expects(:body=).with("--- true\n")
        @handler.process(@mock_request, @mock_response)
    end
    
    it "should return a serialized object when a model save call succeeds" do
        setup_save_request
        @mock_model_instance.stubs(:save).returns(@mock_model_instance)
        @mock_model_instance.expects(:to_yaml).returns('foo')
        @handler.process(@mock_request, @mock_response)        
    end
    
    it "should serialize a controller exception when an exception is thrown by find" do
       setup_find_request
       @mock_model_class.expects(:find).raises(ArgumentError) 
       @mock_response.expects(:status=).with(404)
       @handler.process(@mock_request, @mock_response)        
    end

    it "should serialize a controller exception when an exception is thrown by search" do
        setup_search_request
        @mock_model_class.expects(:search).raises(ArgumentError) 
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)                
    end
    
    it "should serialize a controller exception when an exception is thrown by destroy" do
        setup_destroy_request
        @mock_model_class.expects(:destroy).raises(ArgumentError) 
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)                 
    end
    
    it "should serialize a controller exception when an exception is thrown by save" do
        setup_save_request
        @mock_model_instance.expects(:save).raises(ArgumentError) 
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)                         
    end
    
    it "should serialize a controller exception if the request fails" do
        setup_bad_request     
        @mock_response.expects(:status=).with(404)
        @handler.process(@mock_request, @mock_response)        
    end
end
