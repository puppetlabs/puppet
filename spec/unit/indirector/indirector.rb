#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector, " when managing indirections" do
    before do
        @indirector = Object.new
        @indirector.send(:extend, Puppet::Indirector)
    end

    it "should require a name"

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
        other = Object.new
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
        @indirector = Object.new
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
