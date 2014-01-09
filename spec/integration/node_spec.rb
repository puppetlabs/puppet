#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/node'

describe Puppet::Node do
  describe "when delegating indirection calls" do
    before do
      Puppet::Node.indirection.reset_terminus_class
      Puppet::Node.indirection.cache_class = nil

      @name = "me"
      @node = Puppet::Node.new(@name)
    end

    it "should be able to use the yaml terminus" do
      Puppet::Node.indirection.stubs(:terminus_class).returns :yaml

      # Load now, before we stub the exists? method.
      terminus = Puppet::Node.indirection.terminus(:yaml)

      terminus.expects(:path).with(@name).returns "/my/yaml/file"

      Puppet::FileSystem.expects(:exist?).with("/my/yaml/file").returns false
      Puppet::Node.indirection.find(@name).should be_nil
    end

    it "should have an ldap terminus" do
      Puppet::Node.indirection.terminus(:ldap).should_not be_nil
    end

    it "should be able to use the plain terminus" do
      Puppet::Node.indirection.stubs(:terminus_class).returns :plain

      # Load now, before we stub the exists? method.
      Puppet::Node.indirection.terminus(:plain)

      Puppet::Node.expects(:new).with(@name).returns @node

      Puppet::Node.indirection.find(@name).should equal(@node)
    end

    describe "and using the memory terminus" do
      before do
        @name = "me"
        @terminus = Puppet::Node.indirection.terminus(:memory)
        Puppet::Node.indirection.stubs(:terminus).returns @terminus
        @node = Puppet::Node.new(@name)
      end

      after do
        @terminus.instance_variable_set(:@instances, {})
      end

      it "should find no nodes by default" do
        Puppet::Node.indirection.find(@name).should be_nil
      end

      it "should be able to find nodes that were previously saved" do
        Puppet::Node.indirection.save(@node)
        Puppet::Node.indirection.find(@name).should equal(@node)
      end

      it "should replace existing saved nodes when a new node with the same name is saved" do
        Puppet::Node.indirection.save(@node)
        two = Puppet::Node.new(@name)
        Puppet::Node.indirection.save(two)
        Puppet::Node.indirection.find(@name).should equal(two)
      end

      it "should be able to remove previously saved nodes" do
        Puppet::Node.indirection.save(@node)
        Puppet::Node.indirection.destroy(@node.name)
        Puppet::Node.indirection.find(@name).should be_nil
      end

      it "should fail when asked to destroy a node that does not exist" do
        proc { Puppet::Node.indirection.destroy(@node) }.should raise_error(ArgumentError)
      end
    end
  end
end
