#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector, " when available to a model" do
    before do
        @thingie = Class.new do
            extend Puppet::Indirector
        end
    end

    it "should provide a way for the model to register an indirection under a name" do
        @thingie.should respond_to(:indirects)
    end
end

describe Puppet::Indirector, "when registering an indirection" do
    before do
        @thingie = Class.new do
            extend Puppet::Indirector
        end
    end

    it "should require a name when registering a model" do
        Proc.new {@thingie.send(:indirects) }.should raise_error(ArgumentError)
    end

    it "should create an indirection instance to manage each indirecting model" do
        @indirection = @thingie.indirects(:test)
        @indirection.should be_instance_of(Puppet::Indirector::Indirection)
    end
    
    it "should not allow a model to register under multiple names" do
        # Keep track of the indirection instance so we can delete it on cleanup
        @indirection = @thingie.indirects :first
        Proc.new { @thingie.indirects :second }.should raise_error(ArgumentError)
    end

    it "should make the indirection available via an accessor" do
        @indirection = @thingie.indirects :first
        @thingie.indirection.should equal(@indirection)
    end

    it "should allow specification of a default terminus" do
        klass = mock 'terminus class'
        Puppet::Indirector::Terminus.stubs(:terminus_class).with(:first, :foo).returns(klass)
        @indirection = @thingie.indirects :first, :terminus_class => :foo
        @indirection.terminus_class.should == :foo
    end

    after do
        @indirection.delete if @indirection
    end
end

describe Puppet::Indirector, " when redirecting a model" do
    before do
        @thingie = Class.new do
            extend Puppet::Indirector
        end
        @indirection = @thingie.send(:indirects, :test)
    end

    it "should give the model the ability set a version" do
        thing = @thingie.new
        thing.should respond_to(:version=)
    end

    it "should give the model the ability retrieve a version" do
        thing = @thingie.new
        thing.should respond_to(:version)
    end

    it "should give the model the ability to lookup a model instance by letting the indirection perform the lookup" do
        @indirection.expects(:find)
        @thingie.find
    end

    it "should give the model the ability to remove model instances from a terminus by letting the indirection remove the instance" do
        @indirection.expects(:destroy)
        @thingie.destroy  
    end

    it "should give the model the ability to search for model instances by letting the indirection find the matching instances" do
        @indirection.expects(:search)
        @thingie.search    
    end

    it "should give the model the ability to store a model instance by letting the indirection store the instance" do
        thing = @thingie.new
        @indirection.expects(:save).with(thing)
        thing.save        
    end

    it "should give the model the ability to look up an instance's version by letting the indirection perform the lookup" do
        @indirection.expects(:version).with(:thing)
        @thingie.version(:thing)        
    end

    it "should give the model the ability to set the indirection terminus class" do
        @indirection.expects(:terminus_class=).with(:myterm)
        @thingie.terminus_class = :myterm
    end

    it "should give the model the ability to set the indirection cache class" do
        @indirection.expects(:cache_class=).with(:mycache)
        @thingie.cache_class = :mycache
    end

    after do
        @indirection.delete
    end
end
