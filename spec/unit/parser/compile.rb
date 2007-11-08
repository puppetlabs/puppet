#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Compile, " when compiling" do
    before do
        @node = stub 'node', :name => 'mynode'
        @parser = stub 'parser', :version => "1.0"
        @compile = Puppet::Parser::Compile.new(@node, @parser)
    end

    def compile_methods
        [:set_node_parameters, :evaluate_main, :evaluate_ast_node, :evaluate_node_classes, :evaluate_generators, :fail_on_unevaluated,
            :finish, :store, :extract]
    end

    # Stub all of the main compile methods except the ones we're specifically interested in.
    def compile_stub(*except)
        (compile_methods - except).each { |m| @compile.stubs(m) }
    end

    it "should set node parameters as variables in the top scope" do
        params = {"a" => "b", "c" => "d"}
        @node.stubs(:parameters).returns(params)
        compile_stub(:set_node_parameters)
        @compile.compile
        @compile.topscope.lookupvar("a").should == "b"
        @compile.topscope.lookupvar("c").should == "d"
    end

    it "should evaluate any existing classes named in the node" do
        classes = %w{one two three four}
        main = stub 'main'
        one = stub 'one', :classname => "one"
        three = stub 'three', :classname => "three"
        @node.stubs(:name).returns("whatever")
        @node.stubs(:classes).returns(classes)

        @compile.expects(:evaluate_classes).with(classes, @compile.topscope)
        @compile.send :evaluate_node_classes
    end

    it "should enable ast_nodes if the parser has any nodes" do
        @parser.expects(:nodes).returns(:one => :yay)
        @compile.ast_nodes?.should be_true
    end

    it "should disable ast_nodes if the parser has no nodes" do
        @parser.expects(:nodes).returns({})
        @compile.ast_nodes?.should be_false
    end
end

describe Puppet::Parser::Compile, " when evaluating classes" do
    before do
        @node = stub 'node', :name => 'mynode'
        @parser = stub 'parser', :version => "1.0"
        @scope = stub 'scope', :source => mock("source")
        @compile = Puppet::Parser::Compile.new(@node, @parser)
    end

    it "should fail if there's no source listed for the scope" do
        scope = stub 'scope', :source => nil
        proc { @compile.evaluate_classes(%w{one two}, scope) }.should raise_error(Puppet::DevError)
    end

    it "should tag the configuration with the name of each not-found class" do
        @compile.configuration.expects(:tag).with("notfound")
        @scope.expects(:findclass).with("notfound").returns(nil)
        @compile.evaluate_classes(%w{notfound}, @scope)
    end
end

describe Puppet::Parser::Compile, " when evaluating found classes" do
    before do
        @node = stub 'node', :name => 'mynode'
        @parser = stub 'parser', :version => "1.0"
        @scope = stub 'scope', :source => mock("source")
        @compile = Puppet::Parser::Compile.new(@node, @parser)

        @class = stub 'class', :classname => "my::class"
        @scope.stubs(:findclass).with("myclass").returns(@class)

        @resource = mock 'resource'
    end

    it "should create a resource for each found class" do
        @compile.configuration.stubs(:tag)

        @compile.stubs :store_resource

        Puppet::Parser::Resource.expects(:new).with(:scope => @scope, :source => @scope.source, :title => "my::class", :type => "class").returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope)
    end

    it "should store each created resource in the compile" do
        @compile.configuration.stubs(:tag)

        @compile.expects(:store_resource).with(@scope, @resource)

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope)
    end

    it "should tag the configuration with the fully-qualified name of each found class" do
        @compile.configuration.expects(:tag).with("my::class")

        @compile.stubs(:store_resource)

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope)
    end

    it "should not evaluate the resources created for found classes unless asked" do
        @compile.configuration.stubs(:tag)

        @compile.stubs(:store_resource)
        @resource.expects(:evaluate).never

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope)
    end

    it "should immediately evaluate the resources created for found classes when asked" do
        @compile.configuration.stubs(:tag)

        @compile.stubs(:store_resource)
        @resource.expects(:evaluate)

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope, false)
    end

    it "should return the list of found classes" do
        @compile.configuration.stubs(:tag)

        @compile.stubs(:store_resource)
        @scope.stubs(:findclass).with("notfound").returns(nil)

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass notfound}, @scope).should == %w{myclass}
    end
end
