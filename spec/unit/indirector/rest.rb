#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/rest'

describe Puppet::Indirector::REST do
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @rest_class = Class.new(Puppet::Indirector::REST) do
            def self.to_s
                "This::Is::A::Test::Class"
            end
        end

        @searcher = @rest_class.new
    end

    describe "when doing a find" do
      before :each do
        @searcher.stubs(:network_fetch).returns({:foo => 'bar'}.to_yaml)  # neuter the network connection
        @model.stubs(:from_yaml).returns(@instance)
      end
      
      it "should look up the model instance over the network" do
        @searcher.expects(:network_fetch).returns({:foo => 'bar'}.to_yaml)
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
        @model.stubs(:from_yaml).returns(@instance)
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
      it "should deserialize result data into a list of Model instances"
      it "should generate an error when result data deserializes improperly"
      it "should generate an error when result data specifies an error"      
    end
    
    describe "when doing a save" do
      it "should deserialize result data into a boolean"
      it "should generate an error when result data deserializes improperly"
      it "should generate an error when result data specifies an error"      
    end
    
    describe "when doing a destroy" do
      it "should deserialize result data into a boolean"
      it "should generate an error when result data deserializes improperly"
      it "should generate an error when result data specifies an error"      
    end
end
