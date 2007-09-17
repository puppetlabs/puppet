#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/defaults'
require 'puppet/indirector'

class TestThingie
  extend Puppet::Indirector
  indirects :thingie
end

class TestNormalThingie
end

describe Puppet::Indirector, " when included into a class" do
  before do
    @thingie = Class.new
    @thingie.send(:extend, Puppet::Indirector)
  end

  it "should provide the indirects method to the class" do
    @thingie.should respond_to(:indirects)
  end
  
  it "should require a name to register when indirecting" do
    Proc.new {@thingie.send(:indirects) }.should raise_error(ArgumentError)
  end
  
  it "should require each indirection to be registered under a unique name" do
    @thingie.send(:indirects, :name)
    Proc.new {@thingie.send(:indirects, :name)}.should raise_error(ArgumentError)
  end
  
  it "should not allow a class to register multiple indirections" do
    @thingie.send(:indirects, :first)
    Proc.new {@thingie.send(:indirects, :second)}.should raise_error(ArgumentError)
  end
  
  it "should provide a way to access the list of registered classes"
  
  it "should provide a way to find a class, given the registered name"
  
  it "should make a find method available on the registered class" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:find)
  end
    
  it "should make a destroy method available on the registered class" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:destroy)
  end
  
  it "should make a search method available on the registered class" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:search)
  end
  
  it "should make a save method available on instances of the registered class" do
    @thing = TestThingie.new
    @thing.should respond_to(:save)
  end
    

  
  # when dealing with Terminus methods
  it "should look up the indirection configuration for the registered class when a new instance of that class is created"
  
  it "should use the Terminus described in the class configuration"
  
  it "should use the Terminus find method when calling find on the registered class"
  it "should use the Terminus save method when calling save on the registered class"
  it "should use the Terminus destroy method when calling destroy on the registered class"
  it "should use the Terminus search method when calling search on the registered class"

  it "should allow a registered class to specify its own means of ..."
end







describe Puppet::Indirector, " when managing indirections" do
    before do
        @indirector = Class.new
        @indirector.send(:extend, Puppet::Indirector)
    end

    it "should create an indirection" do
        indirection = @indirector.indirects :test, :to => :node_source
        indirection.name.should == :test
        indirection.to.should == :node_source
    end

    it "should not allow more than one indirection in the same object" do
        @indirector.indirects :test
        proc { @indirector.indirects :else }.should raise_error(ArgumentError)
    end

    it "should allow multiple classes to use the same indirection" do
        @indirector.indirects :test
        other = Class.new
        other.send(:extend, Puppet::Indirector)
        proc { other.indirects :test }.should_not raise_error
    end

    it "should should autoload termini from disk" do
        Puppet::Indirector.expects(:instance_load).with(:test, "puppet/indirector/test")
        @indirector.indirects :test
    end

    after do
        Puppet.config.clear
    end
end

describe Puppet::Indirector, " when performing indirections" do
    before do
        @indirector = Class.new
        @indirector.send(:extend, Puppet::Indirector)
        @indirector.indirects :test, :to => :node_source

        # Set up a fake terminus class that will just be used to spit out
        # mock terminus objects.
        @terminus_class = mock 'terminus_class'
        Puppet::Indirector.stubs(:terminus).with(:test, :test_source).returns(@terminus_class)
        Puppet[:node_source] = "test_source"
    end

    it "should redirect http methods to the default terminus" do
        terminus = mock 'terminus'
        terminus.expects(:put).with("myargument")
        @terminus_class.expects(:new).returns(terminus)
        @indirector.put("myargument")
    end
end
