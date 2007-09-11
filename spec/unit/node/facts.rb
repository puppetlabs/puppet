#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/facts'

describe Puppet::Node::Facts, " when indirecting" do
    before do
        Puppet[:fact_store] = "test_store"
        @terminus_class = mock 'terminus_class'
        @terminus = mock 'terminus'
        @terminus_class.expects(:new).returns(@terminus)
        Puppet::Indirector.expects(:terminus).with(:facts, :test_store).returns(@terminus_class)
    end

    it "should redirect to the specified fact store for retrieval" do
        @terminus.expects(:get).with(:my_facts)
        Puppet::Node::Facts.get(:my_facts)
    end

    it "should redirect to the specified fact store for storage" do
        @terminus.expects(:put).with(:my_facts)
        Puppet::Node::Facts.put(:my_facts)
    end
end
