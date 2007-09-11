#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector, " when managing indirections" do
    before do
        @indirector = Object.new
        @indirector.send(:extend, Puppet::Indirector)
    end

    # LAK:FIXME This seems like multiple tests, but I don't really know how to test one at a time.
    it "should accept specification of an indirection terminus via a configuration parameter" do
        @indirector.indirects :test, :to => :node_source
        Puppet[:node_source] = "test_source"
        klass = mock 'terminus_class'
        terminus = mock 'terminus'
        klass.expects(:new).returns terminus
        Puppet::Indirector.expects(:terminus).with(:test, :test_source).returns(klass)
        @indirector.send(:terminus).should equal(terminus)
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
end

describe Puppet::Indirector, " when managing termini" do
    before do
        @indirector = Object.new
        @indirector.send(:extend, Puppet::Indirector)
    end

    it "should should autoload termini from disk" do
        Puppet::Indirector.expects(:instance_load).with(:test, "puppet/indirector/test")
        @indirector.indirects :test
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

    # Make sure it caches the terminus.
    it "should use the same terminus for all indirections" do
        terminus = mock 'terminus'
        terminus.expects(:put).with("myargument")
        terminus.expects(:get).with("other_argument")
        @terminus_class.expects(:new).returns(terminus)
        @indirector.put("myargument")
        @indirector.get("other_argument")
    end
end
