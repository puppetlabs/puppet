#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/facts'

describe Puppet::Node::Facts, " when indirecting" do
    before do
        @terminus = mock 'terminus'
        Puppet::Indirector.terminus(:facts, Puppet[:fact_store].intern).stubs(:new).returns(@terminus)

        # We have to clear the cache so that the facts ask for our terminus stub,
        # instead of anything that might be cached.
        Puppet::Indirector::Indirection.clear_cache
    end

    it "should redirect to the specified fact store for retrieval" do
        @terminus.expects(:get).with(:my_facts)
        Puppet::Node::Facts.get(:my_facts)
    end

    it "should redirect to the specified fact store for storage" do
        @terminus.expects(:post).with(:my_facts)
        Puppet::Node::Facts.post(:my_facts)
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
