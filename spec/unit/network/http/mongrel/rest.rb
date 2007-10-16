#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../../spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::MongrelREST, "when initializing" do
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

    it "should register itself with the mongrel server for the singular HTTP methods" do
        @mock_mongrel.expects(:register).with do |*args|
            args.first == '/foo' and args.last.is_a? Puppet::Network::HTTP::MongrelREST
        end
        Puppet::Network::HTTP::MongrelREST.new(@params)
    end

    it "should register itself with the mongrel server for the plural GET method" do
        @mock_mongrel.expects(:register).with do |*args|
            args.first == '/foos' and args.last.is_a? Puppet::Network::HTTP::MongrelREST
        end
        Puppet::Network::HTTP::MongrelREST.new(@params)
    end
end

describe Puppet::Network::HTTP::MongrelREST, "when receiving a request" do
    before do
        @mock_request = mock('mongrel http request')
        @mock_response = mock('mongrel http response')
        @mock_model_class = mock('indirected model class')
        Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@mock_model_class)
        @mock_mongrel = mock('mongrel http server')
        @mock_mongrel.stubs(:register)
        @handler = Puppet::Network::HTTP::MongrelREST.new(:server => @mock_mongrel, :handler => :foo)
    end
    
    it "should call the model find method if the request represents a singular HTTP GET" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'GET', Mongrel::Const::REQUEST_PATH => '/foo'})
        @mock_model_class.expects(:find)
        @handler.process(@mock_request, @mock_response)
    end

    it "should call the model search method if the request represents a plural HTTP GET" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'GET', Mongrel::Const::REQUEST_PATH => '/foos'})
        @mock_model_class.expects(:search)
        @handler.process(@mock_request, @mock_response)
    end
    
    it "should call the model destroy method if the request represents an HTTP DELETE" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'DELETE', Mongrel::Const::REQUEST_PATH => '/foo'})
        @mock_model_class.expects(:destroy)
        @handler.process(@mock_request, @mock_response)
    end

    it "should call the model save method if the request represents an HTTP PUT" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'PUT', Mongrel::Const::REQUEST_PATH => '/foo'})
        mock_model_instance = mock('indirected model instance')
        mock_model_instance.expects(:save)
        @mock_model_class.expects(:new).returns(mock_model_instance)
        @handler.process(@mock_request, @mock_response)
    end
    
    it "should fail if the HTTP method isn't supported" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'POST', Mongrel::Const::REQUEST_PATH => '/foo'})
        Proc.new { @handler.process(@mock_request, @mock_response) }.should raise_error(ArgumentError)
    end
    
    it "should fail if the request's pluralization is wrong" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'DELETE', Mongrel::Const::REQUEST_PATH => '/foos'})
        Proc.new { @handler.process(@mock_request, @mock_response) }.should raise_error(ArgumentError)
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'PUT', Mongrel::Const::REQUEST_PATH => '/foos'})
        Proc.new { @handler.process(@mock_request, @mock_response) }.should raise_error(ArgumentError)
    end

    it "should fail if the request is for an unknown path" do
        @mock_request.stubs(:params).returns({ Mongrel::Const::REQUEST_METHOD => 'GET', Mongrel::Const::REQUEST_PATH => '/bar'})
        Proc.new { @handler.process(@mock_request, @mock_response) }.should raise_error(ArgumentError)
    end

    it "should unpack request information from Mongrel"
    
    it "should unpack parameters from the request for passing to controller methods"    
    
    it "should serialize the result from the controller method for return back to Mongrel"
    
    it "should serialize a controller exception result for return back to Mongrel"
end
