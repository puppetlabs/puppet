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
    
    describe "when doing a network fetch" do
      it "should escape the provided path"
      it "should look up the appropriate remote server"
      it "should look up the appropriate remote port"
      it "should use the GET http method"
      it "should use the appropriate remote server"
      it "should use the appropriate remote port"
      it "should use the escaped provided path"
      it "should return the results of the GET request"
    end

    describe "when doing a network delete" do
      it "should escape the provided path"
      it "should look up the appropriate remote server"
      it "should look up the appropriate remote port"
      it "should use the delete http method"
      it "should use the appropriate remote server"
      it "should use the appropriate remote port"
      it "should use the escaped provided path"
      it "should return the results of the DELETE request"
    end
    
    describe "when doing a network put" do
      it "should escape the provided path"
      it "should look up the appropriate remote server"
      it "should look up the appropriate remote port"
      it "should use the delete http method"
      it "should use the appropriate remote server"
      it "should use the appropriate remote port"
      it "should use the escaped provided path"
      it "should return the results of the DELETE request"      
    end

    describe "when doing a find" do
      before :each do
        @result = { :foo => 'bar'}.to_yaml
        @searcher.stubs(:network_fetch).returns(@result)  # neuter the network connection
        @model.stubs(:from_yaml).returns(@instance)
      end
      
      it "should look up the model instance over the network" do
        @searcher.expects(:network_fetch).returns(@result)
        @searcher.find('foo')
      end
      
      it "should look up the model instance using the named indirection" do
        @searcher.expects(:network_fetch).with {|path| path =~ %r{^#{@indirection.name.to_s}/} }.returns(@result)
        @searcher.find('foo')
      end
      
      it "should look up the model instance using the provided key" do
        @searcher.expects(:network_fetch).with {|path| path =~ %r{/foo$} }.returns(@result)
        @searcher.find('foo')
      end
      
      it "should deserialize result data to a Model instance" do
        @model.expects(:from_yaml)
        @searcher.find('foo')
      end
      
      it "should return the deserialized Model instance" do
        @searcher.find('foo').should == @instance     
      end
      
      it "should return nil when deserialized model instance is nil" do
        @model.stubs(:from_yaml).returns(nil)
        @searcher.find('foo').should be_nil
      end
      
      it "should generate an error when result data deserializes improperly" do
        @model.stubs(:from_yaml).raises(ArgumentError)
        lambda { @searcher.find('foo') }.should raise_error(ArgumentError)
      end
      
      it "should generate an error when result data specifies an error" do
        @searcher.stubs(:network_fetch).returns(RuntimeError.new("bogus").to_yaml)
        lambda { @searcher.find('foo') }.should raise_error(RuntimeError)        
      end      
    end

    describe "when doing a search" do
      before :each do
        @result = [1, 2].to_yaml
        @searcher.stubs(:network_fetch).returns(@result)
        @model.stubs(:from_yaml).returns(@instance)
      end
      
      it "should look up the model data over the network" do
        @searcher.expects(:network_fetch).returns(@result)
        @searcher.search('foo')
      end
      
      it "should look up the model instance using the named indirection" do
        @searcher.expects(:network_fetch).with {|path| path =~ %r{^#{@indirection.name.to_s}s/} }.returns(@result)
        @searcher.search('foo')
      end
      
      it "should look up the model instance using the provided key" do
        @searcher.expects(:network_fetch).with {|path| path =~ %r{/foo$} }.returns(@result)
        @searcher.search('foo')
      end
      
      it "should deserialize result data into a list of Model instances" do
        @model.expects(:from_yaml).at_least(2)
        @searcher.search('foo')
      end
      
      it "should generate an error when result data deserializes improperly" do
        @model.stubs(:from_yaml).raises(ArgumentError)
        lambda { @searcher.search('foo') }.should raise_error(ArgumentError)        
      end
      
      it "should generate an error when result data specifies an error" do
        @searcher.stubs(:network_fetch).returns(RuntimeError.new("bogus").to_yaml)
        lambda { @searcher.search('foo') }.should raise_error(RuntimeError)        
      end     
    end    
    
    describe "when doing a destroy" do
      before :each do
        @result = true.to_yaml
        @searcher.stubs(:network_delete).returns(@result)  # neuter the network connection
        @model.stubs(:from_yaml).returns(@instance)
      end
      
      it "should look up the model instance over the network" do
        @searcher.expects(:network_delete).returns(@result)
        @searcher.destroy('foo')
      end
      
      it "should look up the model instance using the named indirection" do
        @searcher.expects(:network_delete).with {|path| path =~ %r{^#{@indirection.name.to_s}/} }.returns(@result)
        @searcher.destroy('foo')
      end
      
      it "should look up the model instance using the provided key" do
        @searcher.expects(:network_delete).with {|path| path =~ %r{/foo$} }.returns(@result)
        @searcher.destroy('foo')
      end
      
      it "should deserialize result data" do
        YAML.expects(:load).with(@result)
        @searcher.destroy('foo')
      end
      
      it "should return deserialized result data" do
        @searcher.destroy('foo').should == true
      end
      
      it "should generate an error when result data specifies an error" do
        @searcher.stubs(:network_delete).returns(RuntimeError.new("bogus").to_yaml)
        lambda { @searcher.destroy('foo') }.should raise_error(RuntimeError)        
      end      
    end

    describe "when doing a save" do
      before :each do
        @result = { :foo => 'bar'}.to_yaml
        @searcher.stubs(:network_put).returns(@result)  # neuter the network connection
        @model.stubs(:from_yaml).returns(@instance)
      end
      
      it "should save the model instance over the network" do
        @searcher.expects(:network_put).returns(@result)
        @searcher.save(@instance)
      end
      
      it "should save the model instance using the named indirection" do
        @searcher.expects(:network_put).with do |path, data| 
          path =~ %r{^#{@indirection.name.to_s}/} and 
          data == @instance.to_yaml 
        end.returns(@result)
        @searcher.save(@instance)
      end
      
      it "should deserialize result data to a Model instance" do
        @model.expects(:from_yaml)
        @searcher.save(@instance)
      end
      
      it "should return the resulting deserialized Model instance" do
        @searcher.save(@instance).should == @instance     
      end
      
      it "should return nil when deserialized model instance is nil" do
        @model.stubs(:from_yaml).returns(nil)
        @searcher.save(@instance).should be_nil
      end
      
      it "should generate an error when result data deserializes improperly" do
        @model.stubs(:from_yaml).raises(ArgumentError)
        lambda { @searcher.save(@instance) }.should raise_error(ArgumentError)
      end
      
      it "should generate an error when result data specifies an error" do
        @searcher.stubs(:network_put).returns(RuntimeError.new("bogus").to_yaml)
        lambda { @searcher.save(@instance) }.should raise_error(RuntimeError)        
      end      
    end
end
