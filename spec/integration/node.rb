#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-23.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/node'

describe Puppet::Node, " when using the memory terminus" do
    before do
        @name = "me"
        @old_terminus = Puppet::Node.indirection.terminus_class
        @terminus = Puppet::Node.indirection.terminus(:memory)
        Puppet::Node.indirection.stubs(:terminus).returns @terminus
        @node = Puppet::Node.new(@name)
    end

    it "should find no nodes by default" do
        Puppet::Node.find(@name).should be_nil
    end

    it "should be able to find nodes that were previously saved" do
        @node.save
        Puppet::Node.find(@name).should equal(@node)
    end

    it "should replace existing saved nodes when a new node with the same name is saved" do
        @node.save
        two = Puppet::Node.new(@name)
        two.save
        Puppet::Node.find(@name).should equal(two)
    end

    it "should be able to remove previously saved nodes" do
        @node.save
        Puppet::Node.destroy(@node)
        Puppet::Node.find(@name).should be_nil
    end

    it "should fail when asked to destroy a node that does not exist" do
        proc { Puppet::Node.destroy(@node) }.should raise_error(ArgumentError)
    end
end
