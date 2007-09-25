#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/node/searching'
require 'puppet/node/facts'

describe Puppet::Node::Searching, " when searching for nodes" do
    before do
        @searcher = Object.new
        @searcher.extend(Puppet::Node::Searching)
        @facts = Puppet::Node::Facts.new("foo", "hostname" => "yay", "domain" => "domain.com")
        @node = Puppet::Node.new("foo")
        Puppet::Node::Facts.stubs(:find).with("foo").returns(@facts)
    end

    it "should search for the node by its key first" do
        names = []
        @searcher.expects(:find).with do |name|
            names << name
            names == %w{foo}
        end.returns(@node)
        @searcher.search("foo").should equal(@node)
    end

    it "should return the first node found using the generated list of names" do
        names = []
        @searcher.expects(:find).with("foo").returns(nil)
        @searcher.expects(:find).with("yay.domain.com").returns(@node)
        @searcher.search("foo").should equal(@node)
    end

    it "should search for the rest of the names inversely by length" do
        names = []
        @facts.values["fqdn"] = "longer.than.the.normal.fqdn.com"
        @searcher.stubs(:find).with do |name|
            names << name
        end
        @searcher.search("foo")
        # Strip off the key
        names.shift

        # And the 'default'
        names.pop

        length = 100
        names.each do |name|
            (name.length < length).should be_true
            length = name.length
        end
    end

    it "should attempt to find a default node if no names are found" do
        names = []
        @searcher.stubs(:find).with do |name|
            names << name
        end.returns(nil)
        @searcher.search("foo")
        names[-1].should == "default"
    end

    it "should cache the nodes" do
        @searcher.expects(:find).with("foo").returns(@node)
        @searcher.search("foo").should equal(@node)
        @searcher.search("foo").should equal(@node)
    end

    it "should flush the node cache using the :filetimeout parameter" do
        node2 = Puppet::Node.new("foo2")
        Puppet[:filetimeout] = -1
        # I couldn't get this to work with :expects
        @searcher.stubs(:find).returns(@node, node2).then.raises(ArgumentError)
        @searcher.search("foo").should equal(@node)
        @searcher.search("foo").should equal(node2)
    end

    after do
        Puppet.settings.clear
    end
end
