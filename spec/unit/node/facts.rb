#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/facts'

describe Puppet::Node::Facts, " when indirecting" do
    before do
        @terminus = mock 'terminus'
        Puppet::Node::Facts.stubs(:indirection).returns(@terminus)

        # We have to clear the cache so that the facts ask for our terminus stub,
        # instead of anything that might be cached.
        Puppet::Indirector::Indirection.clear_cache
        @facts = Puppet::Node::Facts.new("me", "one" => "two")
    end

    it "should redirect to the specified fact store for retrieval" do
        @terminus.expects(:find).with(:my_facts)
        Puppet::Node::Facts.find(:my_facts)
    end

    it "should redirect to the specified fact store for storage" do
        @terminus.expects(:save).with(@facts)
        @facts.save
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
