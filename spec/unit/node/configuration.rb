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

describe Puppet::Node::Configuration, " when functioning as a resource container" do
    before do
        @config = Puppet::Node::Configuration.new("host")
        @one = stub 'resource1', :ref => "Me[you]"
        @two = stub 'resource2', :ref => "Me[him]"
        @dupe = stub 'resource3', :ref => "Me[you]"
    end

    it "should make all vertices available by resource reference" do
        @config.add_resource(@one)
        @config.resource(@one.ref).should equal(@one)
        @config.vertices.find { |r| r.ref == @one.ref }.should equal(@one)
    end

    it "should not allow two resources with the same resource reference" do
        @config.add_resource(@one)
        proc { @config.add_resource(@dupe) }.should raise_error(ArgumentError)
    end

    it "should not store objects that do not respond to :ref" do
        proc { @config.add_resource("thing") }.should raise_error(ArgumentError)
    end

    it "should remove all resources when asked" do
        @config.add_resource @one
        @config.add_resource @two
        @one.expects :remove
        @two.expects :remove
        @config.clear(true)
    end

    it "should support a mechanism for finishing resources" do
        @one.expects :finish
        @two.expects :finish
        @config.add_resource @one
        @config.add_resource @two

        @config.finalize
    end
    
    it "should optionally support an initialization block and should finalize after such blocks" do
        @one.expects :finish
        @two.expects :finish
        config = Puppet::Node::Configuration.new("host") do |conf|
            conf.add_resource @one
            conf.add_resource @two
        end
    end
end

module ApplyingConfigurations
    def setup
        @config = Puppet::Node::Configuration.new("host")

        @config.retrieval_duration = Time.now
        @transaction = mock 'transaction'
        Puppet::Transaction.stubs(:new).returns(@transaction)
        @transaction.stubs(:evaluate)
        @transaction.stubs(:cleanup)
        @transaction.stubs(:addtimes)
    end
end

describe Puppet::Node::Configuration, " when applying" do
    include ApplyingConfigurations

    it "should create and evaluate a transaction" do
        @transaction.expects(:evaluate)
        @config.apply
    end

    it "should provide the configuration time to the transaction" do
        @transaction.expects(:addtimes).with do |arg|
            arg[:config_retrieval].should be_instance_of(Time)
            true
        end
        @config.apply
    end

    it "should clean up the transaction" do
        @transaction.expects :cleanup
        @config.apply
    end
    
    it "should return the transaction" do
        @config.apply.should equal(@transaction)
    end

    it "should yield the transaction if a block is provided" do
        pending "the code works but is not tested"
    end
    
    it "should default to not being a host configuration" do
        @config.host_config.should be_nil
    end
end

describe Puppet::Node::Configuration, " when applying host configurations" do
    include ApplyingConfigurations

    # super() doesn't work in the setup method for some reason
    before do
        @config.host_config = true
    end

    it "should send a report if reporting is enabled" do
        Puppet[:report] = true
        @transaction.expects :send_report
        @config.apply
    end

    it "should send a report if report summaries are enabled" do
        Puppet[:summarize] = true
        @transaction.expects :send_report
        @config.apply
    end

    it "should initialize the state database before applying a configuration" do
        Puppet::Util::Storage.expects(:load)

        # Short-circuit the apply, so we know we're loading before the transaction
        Puppet::Transaction.expects(:new).raises ArgumentError
        proc { @config.apply }.should raise_error(ArgumentError)
    end

    it "should sync the state database after applying" do
        Puppet::Util::Storage.expects(:store)
        @config.apply
    end

    after { Puppet.config.clear }
end

describe Puppet::Node::Configuration, " when applying non-host configurations" do
    include ApplyingConfigurations

    before do
        @config.host_config = false
    end
    
    it "should never send reports" do
        Puppet[:report] = true
        Puppet[:summarize] = true
        @transaction.expects(:send_report).never
        @config.apply
    end

    it "should never modify the state database" do
        Puppet::Util::Storage.expects(:load).never
        Puppet::Util::Storage.expects(:store).never
        @config.apply
    end

    after { Puppet.config.clear }
end
