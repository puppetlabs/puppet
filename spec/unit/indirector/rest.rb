#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/rest'

describe Puppet::Indirector::REST do
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = stub('model')
        @instance = stub('model instance')
        @indirection = stub('indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model)
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @rest_class = Class.new(Puppet::Indirector::REST) do
            def self.to_s
                "This::Is::A::Test::Class"
            end
        end

        @searcher = @rest_class.new
    end
    
    describe "when locating the REST connection" do
      before do
        Puppet.settings.stubs(:value).returns("whatever")
      end

      it "should return the :server setting as the host" do
        Puppet.settings.expects(:value).with(:server).returns "myserver"
        @searcher.rest_connection_details[:host].should == "myserver"
      end
      
      it "should return the :masterport (as an Integer) as the port" do
        Puppet.settings.expects(:value).with(:masterport).returns "1234"
        @searcher.rest_connection_details[:port].should == 1234
      end
    end
    
    describe "when doing a network fetch" do
      before :each do
        Net::HTTP.stubs(:start).returns('result')
        @details = { :host => '127.0.0.1', :port => 34343 }
        @searcher.stubs(:rest_connection_details).returns(@details)
      end
      
      it "should accept a path" do
        lambda { @search.network_fetch('foo') }.should_not raise_error(ArgumentError)
      end
      
      it "should require a path" do
        lambda { @searcher.network_fetch }.should raise_error(ArgumentError)
      end
            
      it "should look up connection details" do
        @searcher.expects(:rest_connection_details).returns(@details)
        @searcher.network_fetch('foo')
      end
      
      it "should use the GET http method" do
        @mock_result = stub('mock result', :body => 'result')
        @mock_connection = mock('mock http connection', :get => @mock_result)
        @searcher.stubs(:network).yields(@mock_connection)
        @searcher.network_fetch('foo')
      end
      
      it "should use the appropriate remote server" do
        Net::HTTP.expects(:start).with {|host, port| host == @details[:host] }
        @searcher.network_fetch('foo')
      end
      
      it "should use the appropriate remote port" do
        Net::HTTP.expects(:start).with {|host, port| port == @details[:port] }
        @searcher.network_fetch('foo')
      end
      
      it "should use the provided path" do
        @mock_result = stub('mock result', :body => 'result')
        @mock_connection = stub('mock http connection')
        @mock_connection.expects(:get).with('/foo').returns(@mock_result)
        @searcher.stubs(:network).yields(@mock_connection)
        @searcher.network_fetch('foo')
      end
                
      it "should return the results of the GET request" do
        @searcher.network_fetch('foo').should == 'result'        
      end
    end

    describe "when doing a network delete" do
      before :each do
        Net::HTTP.stubs(:start).returns('result')
        @details = { :host => '127.0.0.1', :port => 34343 }
        @searcher.stubs(:rest_connection_details).returns(@details)
      end
      
      it "should accept a path" do
        lambda { @search.network_delete('foo') }.should_not raise_error(ArgumentError)
      end
      
      it "should require a path" do
        lambda { @searcher.network_delete }.should raise_error(ArgumentError)
      end
            
      it "should look up connection details" do
        @searcher.expects(:rest_connection_details).returns(@details)
        @searcher.network_delete('foo')
      end
      
      it "should use the DELETE http method" do
        @mock_result = stub('mock result', :body => 'result')
        @mock_connection = mock('mock http connection', :delete => @mock_result)
        @searcher.stubs(:network).yields(@mock_connection)
        @searcher.network_delete('foo')
      end
      
      it "should use the appropriate remote server" do
        Net::HTTP.expects(:start).with {|host, port| host == @details[:host] }
        @searcher.network_delete('foo')
      end
      
      it "should use the appropriate remote port" do
        Net::HTTP.expects(:start).with {|host, port| port == @details[:port] }
        @searcher.network_delete('foo')
      end
      
      it "should use the provided path" do
        @mock_result = stub('mock result', :body => 'result')
        @mock_connection = stub('mock http connection')
        @mock_connection.expects(:delete).with('/foo').returns(@mock_result)
        @searcher.stubs(:network).yields(@mock_connection)
        @searcher.network_delete('foo')
      end
            
      it "should return the results of the DELETE request" do
        @searcher.network_delete('foo').should == 'result'        
      end    
    end
    
    describe "when doing a network put" do
      before :each do
        Net::HTTP.stubs(:start).returns('result')
        @details = { :host => '127.0.0.1', :port => 34343 }
        @data = { :foo => 'bar' }
        @searcher.stubs(:rest_connection_details).returns(@details)
      end
      
      it "should accept a path and data" do
        lambda { @search.network_put('foo', @data) }.should_not raise_error(ArgumentError)
      end
      
      it "should require a path and data" do
        lambda { @searcher.network_put('foo') }.should raise_error(ArgumentError)
      end
      
      it "should look up connection details" do
        @searcher.expects(:rest_connection_details).returns(@details)
        @searcher.network_put('foo', @data)
      end
      
      it "should use the appropriate remote server" do
        Net::HTTP.expects(:start).with {|host, port| host == @details[:host] }
        @searcher.network_put('foo', @data)
      end
      
      it "should use the appropriate remote port" do
        Net::HTTP.expects(:start).with {|host, port| port == @details[:port] }
        @searcher.network_put('foo', @data)
      end
      
      it "should use the PUT http method" do
        @mock_result = stub('mock result', :body => 'result')
        @mock_connection = mock('mock http connection', :put => @mock_result)
        @searcher.stubs(:network).yields(@mock_connection)
        @searcher.network_put('foo', @data)
      end
      
      it "should use the provided path" do
        @mock_result = stub('mock result', :body => 'result')
        @mock_connection = stub('mock http connection')
        @mock_connection.expects(:put).with {|path, data| path == '/foo' }.returns(@mock_result)
        @searcher.stubs(:network).yields(@mock_connection)
        @searcher.network_put('foo', @data)        
      end
      
      it "should use the provided data" do
        @mock_result = stub('mock result', :body => 'result')
        @mock_connection = stub('mock http connection')
        @mock_connection.expects(:put).with {|path, data| data == @data }.returns(@mock_result)
        @searcher.stubs(:network).yields(@mock_connection)
        @searcher.network_put('foo', @data)                
      end
      
      it "should return the results of the PUT request" do
        @searcher.network_put('foo', @data).should == 'result'        
      end    
    end

    describe "when doing a find" do
      before :each do
        @result = { :foo => 'bar'}.to_yaml
        @searcher.stubs(:network_fetch).returns(@result)  # neuter the network connection
        @model.stubs(:from_yaml).returns(@instance)

        @request = stub 'request', :key => 'foo'
      end
      
      it "should look up the model instance over the network" do
        @searcher.expects(:network_fetch).returns(@result)
        @searcher.find(@request)
      end
      
      it "should look up the model instance using the named indirection" do
        @searcher.expects(:network_fetch).with {|path| path =~ %r{^#{@indirection.name.to_s}/} }.returns(@result)
        @searcher.find(@request)
      end
      
      it "should look up the model instance using the provided key" do
        @searcher.expects(:network_fetch).with {|path| path =~ %r{/foo$} }.returns(@result)
        @searcher.find(@request)
      end
      
      it "should deserialize result data to a Model instance" do
        @model.expects(:from_yaml)
        @searcher.find(@request)
      end
      
      it "should return the deserialized Model instance" do
        @searcher.find(@request).should == @instance     
      end
      
      it "should return nil when deserialized model instance is nil" do
        @model.stubs(:from_yaml).returns(nil)
        @searcher.find(@request).should be_nil
      end
      
      it "should generate an error when result data deserializes improperly" do
        @model.stubs(:from_yaml).raises(ArgumentError)
        lambda { @searcher.find(@request) }.should raise_error(ArgumentError)
      end
      
      it "should generate an error when result data specifies an error" do
        @searcher.stubs(:network_fetch).returns(RuntimeError.new("bogus").to_yaml)
        lambda { @searcher.find(@request) }.should raise_error(RuntimeError)        
      end      
    end

    describe "when doing a search" do
      before :each do
        @result = [1, 2].to_yaml
        @searcher.stubs(:network_fetch).returns(@result)
        @model.stubs(:from_yaml).returns(@instance)

        @request = stub 'request', :key => 'foo'
      end
      
      it "should look up the model data over the network" do
        @searcher.expects(:network_fetch).returns(@result)
        @searcher.search(@request)
      end
      
      it "should look up the model instance using the named indirection" do
        @searcher.expects(:network_fetch).with {|path| path =~ %r{^#{@indirection.name.to_s}s/} }.returns(@result)
        @searcher.search(@request)
      end
      
      it "should look up the model instance using the provided key" do
        @searcher.expects(:network_fetch).with {|path| path =~ %r{/foo$} }.returns(@result)
        @searcher.search(@request)
      end
      
      it "should deserialize result data into a list of Model instances" do
        @model.expects(:from_yaml).at_least(2)
        @searcher.search(@request)
      end
      
      it "should generate an error when result data deserializes improperly" do
        @model.stubs(:from_yaml).raises(ArgumentError)
        lambda { @searcher.search(@request) }.should raise_error(ArgumentError)        
      end
      
      it "should generate an error when result data specifies an error" do
        @searcher.stubs(:network_fetch).returns(RuntimeError.new("bogus").to_yaml)
        lambda { @searcher.search(@request) }.should raise_error(RuntimeError)        
      end     
    end    
    
    describe "when doing a destroy" do
      before :each do
        @result = true.to_yaml
        @searcher.stubs(:network_delete).returns(@result)  # neuter the network connection
        @model.stubs(:from_yaml).returns(@instance)

        @request = stub 'request', :key => 'foo'
      end
      
      it "should look up the model instance over the network" do
        @searcher.expects(:network_delete).returns(@result)
        @searcher.destroy(@request)
      end
      
      it "should look up the model instance using the named indirection" do
        @searcher.expects(:network_delete).with {|path| path =~ %r{^#{@indirection.name.to_s}/} }.returns(@result)
        @searcher.destroy(@request)
      end
      
      it "should look up the model instance using the provided key" do
        @searcher.expects(:network_delete).with {|path| path =~ %r{/foo$} }.returns(@result)
        @searcher.destroy(@request)
      end
      
      it "should deserialize result data" do
        YAML.expects(:load).with(@result)
        @searcher.destroy(@request)
      end
      
      it "should return deserialized result data" do
        @searcher.destroy(@request).should == true
      end
      
      it "should generate an error when result data specifies an error" do
        @searcher.stubs(:network_delete).returns(RuntimeError.new("bogus").to_yaml)
        lambda { @searcher.destroy(@request) }.should raise_error(RuntimeError)        
      end      
    end

    describe "when doing a save" do
      before :each do
        @result = { :foo => 'bar'}.to_yaml
        @searcher.stubs(:network_put).returns(@result)  # neuter the network connection
        @model.stubs(:from_yaml).returns(@instance)

        @request = stub 'request', :instance => @instance
      end
      
      it "should save the model instance over the network" do
        @searcher.expects(:network_put).returns(@result)
        @searcher.save(@request)
      end
      
      it "should save the model instance using the named indirection" do
        @searcher.expects(:network_put).with do |path, data| 
          path =~ %r{^#{@indirection.name.to_s}/} and 
          data == @instance.to_yaml 
        end.returns(@result)
        @searcher.save(@request)
      end
      
      it "should deserialize result data to a Model instance" do
        @model.expects(:from_yaml)
        @searcher.save(@request)
      end
      
      it "should return the resulting deserialized Model instance" do
        @searcher.save(@request).should == @instance     
      end
      
      it "should return nil when deserialized model instance is nil" do
        @model.stubs(:from_yaml).returns(nil)
        @searcher.save(@request).should be_nil
      end
      
      it "should generate an error when result data deserializes improperly" do
        @model.stubs(:from_yaml).raises(ArgumentError)
        lambda { @searcher.save(@request) }.should raise_error(ArgumentError)
      end
      
      it "should generate an error when result data specifies an error" do
        @searcher.stubs(:network_put).returns(RuntimeError.new("bogus").to_yaml)
        lambda { @searcher.save(@request) }.should raise_error(RuntimeError)        
      end      
    end
end
