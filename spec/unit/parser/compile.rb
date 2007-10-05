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
        @compile.parser.expects(:findclass).with("", "").returns(main)
        @compile.parser.expects(:findclass).with("", "one").returns(one)
        @compile.parser.expects(:findclass).with("", "two").returns(nil)
        @compile.parser.expects(:findclass).with("", "three").returns(three)
        @compile.parser.expects(:findclass).with("", "four").returns(nil)
        @node.stubs(:classes).returns(classes)
        @compile.send :evaluate_main
        @compile.send :evaluate_node_classes

        # Now make sure we've created the appropriate resources.
        @compile.resources.find { |r| r.to_s == "Class[one]" }.should be_an_instance_of(Puppet::Parser::Resource)
        @compile.resources.find { |r| r.to_s == "Class[three]" }.should be_an_instance_of(Puppet::Parser::Resource)
        @compile.resources.find { |r| r.to_s == "Class[two]" }.should be_nil
        @compile.resources.find { |r| r.to_s == "Class[four]" }.should be_nil
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
