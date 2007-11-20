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

describe Puppet::Parser::Compile, " when evaluating collections" do
    before do
        @node = stub 'node', :name => 'mynode'
        @parser = stub 'parser', :version => "1.0"
        @scope = stub 'scope', :source => mock("source")
        @compile = Puppet::Parser::Compile.new(@node, @parser)
    end

    it "should evaluate each collection" do
        2.times { |i|
            coll = mock 'coll%s' % i
            @compile.add_collection(coll)
            
            # This is the hard part -- we have to emulate the fact that
            # collections delete themselves if they are done evaluating.
            coll.expects(:evaluate).with do
                @compile.delete_collection(coll)
            end
        }

        @compile.class.publicize_methods(:evaluate_collections) { @compile.evaluate_collections }
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

describe Puppet::Parser::Compile, " when evaluating AST nodes with no AST nodes present" do
    before do
        @node = stub 'node', :name => "foo"
        @parser = stub 'parser', :version => "1.0", :nodes => {}
        @compile = Puppet::Parser::Compile.new(@node, @parser)
    end

    it "should do nothing" do
        @compile.expects(:ast_nodes?).returns(false)
        @compile.parser.expects(:nodes).never
        Puppet::Parser::Resource.expects(:new).never

        @compile.send(:evaluate_ast_node)
    end
end

describe Puppet::Parser::Compile, " when evaluating AST nodes with AST nodes present" do
    before do
        @node = stub 'node', :name => "foo"
        @parser = stub 'parser', :version => "1.0", :nodes => {}
        @compile = Puppet::Parser::Compile.new(@node, @parser)

        @nodes = mock 'node_hash'
        @compile.stubs(:ast_nodes?).returns(true)
        @compile.parser.stubs(:nodes).returns(@nodes)

        # Set some names for our test
        @node.stubs(:names).returns(%w{a b c})
        @nodes.stubs(:[]).with("a").returns(nil)
        @nodes.stubs(:[]).with("b").returns(nil)
        @nodes.stubs(:[]).with("c").returns(nil)

        # It should check this last, of course.
        @nodes.stubs(:[]).with("default").returns(nil)
    end

    it "should fail if the named node cannot be found" do
        proc { @compile.send(:evaluate_ast_node) }.should raise_error(Puppet::ParseError)
    end

    it "should create a resource for the first node class matching the node name" do
        node_class = stub 'node', :classname => "c"
        @nodes.stubs(:[]).with("c").returns(node_class)

        node_resource = stub 'node resource', :ref => "Node[c]", :evaluate => nil
        Puppet::Parser::Resource.expects(:new).with { |args| args[:title] == "c" and args[:type] == "node" }.returns(node_resource)

        @compile.send(:evaluate_ast_node)
    end

    it "should match the default node if no matching node can be found" do
        node_class = stub 'node', :classname => "default"
        @nodes.stubs(:[]).with("default").returns(node_class)

        node_resource = stub 'node resource', :ref => "Node[default]", :evaluate => nil
        Puppet::Parser::Resource.expects(:new).with { |args| args[:title] == "default" and args[:type] == "node" }.returns(node_resource)

        @compile.send(:evaluate_ast_node)
    end

    it "should tag the configuration with the found node name" do
        node_class = stub 'node', :classname => "c"
        @nodes.stubs(:[]).with("c").returns(node_class)

        node_resource = stub 'node resource', :ref => "Node[c]", :evaluate => nil
        Puppet::Parser::Resource.stubs(:new).returns(node_resource)

        @compile.configuration.expects(:tag).with("c")
        @compile.send(:evaluate_ast_node)
    end

    it "should evaluate the node resource immediately rather than using lazy evaluation" do
        node_class = stub 'node', :classname => "c"
        @nodes.stubs(:[]).with("c").returns(node_class)

        node_resource = stub 'node resource', :ref => "Node[c]"
        Puppet::Parser::Resource.stubs(:new).returns(node_resource)

        node_resource.expects(:evaluate)

        @compile.send(:evaluate_ast_node)
    end

    it "should set the node's scope as the top scope" do
        node_class = stub 'node', :classname => "c"
        @nodes.stubs(:[]).with("c").returns(node_class)

        node_resource = stub 'node resource', :ref => "Node[c]"
        Puppet::Parser::Resource.stubs(:new).returns(node_resource)

        # The #evaluate method normally does this.
        @compile.class_set(node_class.classname, :my_node_scope)
        node_resource.stubs(:evaluate)

        @compile.send(:evaluate_ast_node)

        @compile.topscope.should == :my_node_scope
    end
end
