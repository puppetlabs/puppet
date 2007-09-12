#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/indirector'
require 'puppet/node/facts'

describe Puppet::Indirector.terminus(:node, :none), " when searching for nodes" do
    before do
        Puppet.config[:node_source] = "none"
        @searcher = Puppet::Indirector.terminus(:node, :none).new
    end

    it "should create a node instance" do
        @searcher.get("yay").should be_instance_of(Puppet::Node)
    end

    it "should create a new node with the correct name" do
        @searcher.get("yay").name.should == "yay"
    end

    it "should merge the node's facts" do
        facts = Puppet::Node::Facts.new("yay", "one" => "two", "three" => "four")
        Puppet::Node::Facts.expects(:get).with("yay").returns(facts)
        node = @searcher.get("yay")
        node.parameters["one"].should == "two"
        node.parameters["three"].should == "four"
    end

    after do
        Puppet.config.clear
    end
end
