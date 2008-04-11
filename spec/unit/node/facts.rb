#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/facts'

describe Puppet::Node::Facts, " when indirecting" do
    before do
        @indirection = stub 'indirection', :request => mock('request'), :name => :facts

        # We have to clear the cache so that the facts ask for our indirection stub,
        # instead of anything that might be cached.
        Puppet::Indirector::Indirection.clear_cache
        @facts = Puppet::Node::Facts.new("me", "one" => "two")
    end

    it "should redirect to the specified fact store for retrieval" do
        Puppet::Node::Facts.stubs(:indirection).returns(@indirection)
        @indirection.expects(:find)
        Puppet::Node::Facts.find(:my_facts)
    end

    it "should redirect to the specified fact store for storage" do
        Puppet::Node::Facts.stubs(:indirection).returns(@indirection)
        @indirection.expects(:save)
        @facts.save
    end

    it "should default to the 'facter' terminus" do
        Puppet::Node::Facts.indirection.terminus_class.should == :facter
    end

    after do
        mocha_verify
        Puppet::Indirector::Indirection.clear_cache
    end
end

describe Puppet::Node::Facts, " when storing and retrieving" do
    it "should add metadata to the facts" do
        facts = Puppet::Node::Facts.new("me", "one" => "two", "three" => "four")
        facts.values[:_timestamp].should be_instance_of(Time)
    end
end
