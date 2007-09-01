#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Compile, " when compiling" do
    before do
        @node = mock 'node'
        @parser = mock 'parser'
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
        one = stub 'one'
        one.expects(:safeevaluate).with(:scope => @compile.topscope)
        three = stub 'three'
        three.expects(:safeevaluate).with(:scope => @compile.topscope)
        @node.stubs(:name).returns("whatever")
        @compile.parser.expects(:findclass).with("", "").returns(main)
        @compile.parser.expects(:findclass).with("", "one").returns(one)
        @compile.parser.expects(:findclass).with("", "two").returns(nil)
        @compile.parser.expects(:findclass).with("", "three").returns(three)
        @compile.parser.expects(:findclass).with("", "four").returns(nil)
        @node.stubs(:classes).returns(classes)
        compile_stub(:evaluate_node_classes)
        @compile.compile
    end
end
