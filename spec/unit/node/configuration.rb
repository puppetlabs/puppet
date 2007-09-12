#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Node::Configuration, " when compiling" do
    it "should accept tags" do
        config = Puppet::Node::Configuration.new("mynode")
        config.tag("one")
        config.tags.should == %w{one}
    end

    it "should accept multiple tags at once" do
        config = Puppet::Node::Configuration.new("mynode")
        config.tag("one", "two")
        config.tags.should == %w{one two}
    end

    it "should convert all tags to strings" do
        config = Puppet::Node::Configuration.new("mynode")
        config.tag("one", :two)
        config.tags.should == %w{one two}
    end

    it "should tag with both the qualified name and the split name" do
        config = Puppet::Node::Configuration.new("mynode")
        config.tag("one::two")
        config.tags.include?("one").should be_true
        config.tags.include?("one::two").should be_true
    end

    it "should accept classes" do
        config = Puppet::Node::Configuration.new("mynode")
        config.add_class("one")
        config.classes.should == %w{one}
        config.add_class("two", "three")
        config.classes.should == %w{one two three}
    end

    it "should tag itself with passed class names" do
        config = Puppet::Node::Configuration.new("mynode")
        config.add_class("one")
        config.tags.should == %w{one}
    end
end

describe Puppet::Node::Configuration, " when extracting" do
    it "should return extraction result as the method result" do
        config = Puppet::Node::Configuration.new("mynode")
        config.expects(:extraction_format).returns(:whatever)
        config.expects(:extract_to_whatever).returns(:result)
        config.extract.should == :result
    end
end

describe Puppet::Node::Configuration, " when extracting transobjects" do

    def mkscope
        @parser = Puppet::Parser::Parser.new :Code => ""
        @node = Puppet::Node.new("mynode")
        @compile = Puppet::Parser::Compile.new(@node, @parser)

        # XXX This is ridiculous.
        @compile.send(:evaluate_main)
        @scope = @compile.topscope
    end

    def mkresource(type, name)
        Puppet::Parser::Resource.new(:type => type, :title => name, :source => @source, :scope => @scope)
    end

    # This isn't really a spec-style test, but I don't know how better to do it.
    it "should transform the resource graph into a tree of TransBuckets and TransObjects" do
        config = Puppet::Node::Configuration.new("mynode")

        @scope = mkscope
        @source = mock 'source'

        defined = mkresource("class", :main)
        builtin = mkresource("file", "/yay")

        config.add_edge!(defined, builtin)

        bucket = []
        bucket.expects(:classes=).with(config.classes)
        defined.stubs(:builtin?).returns(false)
        defined.expects(:to_transbucket).returns(bucket)
        builtin.expects(:to_transobject).returns(:builtin)

        config.extract_to_transportable.should == [:builtin]
    end

    # Now try it with a more complicated graph -- a three tier graph, each tier
    it "should transform arbitrarily deep graphs into isomorphic trees" do
        config = Puppet::Node::Configuration.new("mynode")

        @scope = mkscope
        @scope.stubs(:tags).returns([])
        @source = mock 'source'

        # Create our scopes.
        top = mkresource "class", :main
        topbucket = []
        topbucket.expects(:classes=).with([])
        top.expects(:to_trans).returns(topbucket)
        topres = mkresource "file", "/top"
        topres.expects(:to_trans).returns(:topres)
        config.add_edge! top, topres

        middle = mkresource "class", "middle"
        middle.expects(:to_trans).returns([])
        config.add_edge! top, middle
        midres = mkresource "file", "/mid"
        midres.expects(:to_trans).returns(:midres)
        config.add_edge! middle, midres

        bottom = mkresource "class", "bottom"
        bottom.expects(:to_trans).returns([])
        config.add_edge! middle, bottom
        botres = mkresource "file", "/bot"
        botres.expects(:to_trans).returns(:botres)
        config.add_edge! bottom, botres

        toparray = config.extract_to_transportable

        # This is annoying; it should look like:
        #   [[[:botres], :midres], :topres]
        # but we can't guarantee sort order.
        toparray.include?(:topres).should be_true

        midarray = toparray.find { |t| t.is_a?(Array) }
        midarray.include?(:midres).should be_true
        botarray = midarray.find { |t| t.is_a?(Array) }
        botarray.include?(:botres).should be_true
    end
end

describe Puppet::Node::Configuration, " functioning as a resource container" do
    before do
        @graph = Puppet::Node::Configuration.new("host")
        @one = stub 'resource1', :ref => "Me[you]"
        @two = stub 'resource2', :ref => "Me[him]"
        @dupe = stub 'resource3', :ref => "Me[you]"
    end

    it "should make all vertices available by resource reference" do
        @graph.add_resource(@one)
        @graph.resource(@one.ref).should equal(@one)
    end

    it "should not allow two resources with the same resource reference" do
        @graph.add_resource(@one)
        proc { @graph.add_resource(@dupe) }.should raise_error(ArgumentError)
    end

    it "should not store objects that do not respond to :ref" do
        proc { @graph.add_resource("thing") }.should raise_error(ArgumentError)
    end
end
