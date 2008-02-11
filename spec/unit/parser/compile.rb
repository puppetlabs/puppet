#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

module CompileTesting
    def setup
        @node = Puppet::Node.new "testnode"
        @parser = Puppet::Parser::Parser.new :environment => "development"

        @scope = stub 'scope', :resource => stub("scope_resource"), :source => mock("source")
        @compile = Puppet::Parser::Compile.new(@node, @parser)
    end
end

describe Puppet::Parser::Compile, " when compiling" do
    include CompileTesting

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
        @compile.class.publicize_methods(:evaluate_node_classes) { @compile.evaluate_node_classes }
    end

    it "should enable ast_nodes if the parser has any nodes" do
        @parser.expects(:nodes).returns(:one => :yay)
        @compile.ast_nodes?.should be_true
    end

    it "should disable ast_nodes if the parser has no nodes" do
        @parser.expects(:nodes).returns({})
        @compile.ast_nodes?.should be_false
    end

    it "should evaluate the main class if it exists" do
        compile_stub(:evaluate_main)
        main_class = mock 'main_class'
        main_class.expects(:evaluate_code).with { |r| r.is_a?(Puppet::Parser::Resource) }
        @compile.topscope.expects(:source=).with(main_class)
        @parser.stubs(:findclass).with("", "").returns(main_class)

        @compile.compile
    end

    it "should evaluate any node classes" do
        @node.stubs(:classes).returns(%w{one two three four})
        @compile.expects(:evaluate_classes).with(%w{one two three four}, @compile.topscope)
        @compile.send(:evaluate_node_classes)
    end

    it "should evaluate all added collections" do
        colls = []
        # And when the collections fail to evaluate.
        colls << mock("coll1-false")
        colls << mock("coll2-false")
        colls.each { |c| c.expects(:evaluate).returns(false) }

        @compile.add_collection(colls[0])
        @compile.add_collection(colls[1])

        compile_stub(:evaluate_generators)
        @compile.compile
    end

    it "should ignore builtin resources" do
        resource = stub 'builtin', :ref => "File[testing]", :builtin? => true

        scope = stub 'scope', :resource => stub("scope_resource")
        @compile.store_resource(scope, resource)
        resource.expects(:evaluate).never
        
        @compile.compile
    end

    it "should evaluate unevaluated resources" do
        resource = stub 'notevaluated', :ref => "File[testing]", :builtin? => false, :evaluated? => false
        scope = stub 'scope', :resource => stub("scope_resource")
        @compile.store_resource(scope, resource)

        # We have to now mark the resource as evaluated
        resource.expects(:evaluate).with { |*whatever| resource.stubs(:evaluated?).returns true }
        
        @compile.compile
    end

    it "should not evaluate already-evaluated resources" do
        resource = stub 'already_evaluated', :ref => "File[testing]", :builtin? => false, :evaluated? => true
        scope = stub 'scope', :resource => stub("scope_resource")
        @compile.store_resource(scope, resource)
        resource.expects(:evaluate).never
        
        @compile.compile
    end

    it "should evaluate unevaluated resources created by evaluating other resources" do
        resource = stub 'notevaluated', :ref => "File[testing]", :builtin? => false, :evaluated? => false
        scope = stub 'scope', :resource => stub("scope_resource")
        @compile.store_resource(scope, resource)

        resource2 = stub 'created', :ref => "File[other]", :builtin? => false, :evaluated? => false

        # We have to now mark the resource as evaluated
        resource.expects(:evaluate).with { |*whatever| resource.stubs(:evaluated?).returns(true); @compile.store_resource(scope, resource2) }
        resource2.expects(:evaluate).with { |*whatever| resource2.stubs(:evaluated?).returns(true) }

        
        @compile.compile
    end

    it "should call finish() on all resources" do
        # Add a resource that does respond to :finish
        yep = stub "finisher", :ref => "File[finish]"
        yep.expects(:respond_to?).with(:finish).returns(true)
        yep.expects(:finish)

        @compile.store_resource(@scope, yep)

        # And one that does not
        dnf = stub "dnf", :ref => "File[dnf]"
        dnf.expects(:respond_to?).with(:finish).returns(false)

        @compile.store_resource(@scope, dnf)

        @compile.send(:finish)
    end

    it "should add resources that do not conflict with existing resources" do
        resource = stub "noconflict", :ref => "File[yay]"
        @compile.store_resource(@scope, resource)

        @compile.catalog.should be_vertex(resource)
    end

    it "should not fail when conflicting resources are non-isormphic" do
        type = stub 'faketype', :isomorphic? => false, :name => "mytype"
        Puppet::Type.stubs(:type).with("mytype").returns(type)

        resource1 = stub "iso1conflict", :ref => "Mytype[yay]", :type => "mytype"
        resource2 = stub "iso2conflict", :ref => "Mytype[yay]", :type => "mytype"

        @compile.store_resource(@scope, resource1)
        lambda { @compile.store_resource(@scope, resource2) }.should_not raise_error
    end

    it "should fail to add resources that conflict with existing resources" do
        type = stub 'faketype', :isomorphic? => true, :name => "mytype"
        Puppet::Type.stubs(:type).with("mytype").returns(type)

        resource1 = stub "iso1conflict", :ref => "Mytype[yay]", :type => "mytype", :file => "eh", :line => 0
        resource2 = stub "iso2conflict", :ref => "Mytype[yay]", :type => "mytype", :file => "eh", :line => 0

        @compile.store_resource(@scope, resource1)
        lambda { @compile.store_resource(@scope, resource2) }.should raise_error(Puppet::ParseError)
    end

    it "should have a method for looking up resources" do
        resource = stub 'resource', :ref => "Yay[foo]"
        @compile.store_resource(@scope, resource)
        @compile.findresource("Yay[foo]").should equal(resource)
    end

    it "should be able to look resources up by type and title" do
        resource = stub 'resource', :ref => "Yay[foo]"
        @compile.store_resource(@scope, resource)
        @compile.findresource("Yay", "foo").should equal(resource)
    end
end

describe Puppet::Parser::Compile, " when evaluating classes" do
    include CompileTesting

    it "should fail if there's no source listed for the scope" do
        scope = stub 'scope', :source => nil
        proc { @compile.evaluate_classes(%w{one two}, scope) }.should raise_error(Puppet::DevError)
    end

    it "should tag the catalog with the name of each not-found class" do
        @compile.catalog.expects(:tag).with("notfound")
        @scope.expects(:findclass).with("notfound").returns(nil)
        @compile.evaluate_classes(%w{notfound}, @scope)
    end
end

describe Puppet::Parser::Compile, " when evaluating collections" do
    include CompileTesting

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

    it "should not fail when there are unevaluated resource collections that do not refer to specific resources" do
        coll = stub 'coll', :evaluate => false
        coll.expects(:resources).returns(nil)

        @compile.add_collection(coll)

        lambda { @compile.compile }.should_not raise_error
    end

    it "should fail when there are unevaluated resource collections that refer to a specific resource" do
        coll = stub 'coll', :evaluate => false
        coll.expects(:resources).returns(:something)

        @compile.add_collection(coll)

        lambda { @compile.compile }.should raise_error(Puppet::ParseError)
    end

    it "should fail when there are unevaluated resource collections that refer to multiple specific resources" do
        coll = stub 'coll', :evaluate => false
        coll.expects(:resources).returns([:one, :two])

        @compile.add_collection(coll)

        lambda { @compile.compile }.should raise_error(Puppet::ParseError)
    end
end


describe Puppet::Parser::Compile, " when evaluating found classes" do
    include CompileTesting

    before do
        @class = stub 'class', :classname => "my::class"
        @scope.stubs(:findclass).with("myclass").returns(@class)

        @resource = stub 'resource', :ref => 'Class[myclass]'
    end

    it "should create a resource for each found class" do
        @compile.catalog.stubs(:tag)

        @compile.stubs :store_resource

        Puppet::Parser::Resource.expects(:new).with(:scope => @scope, :source => @scope.source, :title => "my::class", :type => "class").returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope)
    end

    it "should store each created resource in the compile" do
        @compile.catalog.stubs(:tag)

        @compile.expects(:store_resource).with(@scope, @resource)

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope)
    end

    it "should tag the catalog with the fully-qualified name of each found class" do
        @compile.catalog.expects(:tag).with("my::class")

        @compile.stubs(:store_resource)

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope)
    end

    it "should not evaluate the resources created for found classes unless asked" do
        @compile.catalog.stubs(:tag)

        @compile.stubs(:store_resource)
        @resource.expects(:evaluate).never

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope)
    end

    it "should immediately evaluate the resources created for found classes when asked" do
        @compile.catalog.stubs(:tag)

        @compile.stubs(:store_resource)
        @resource.expects(:evaluate)

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass}, @scope, false)
    end

    it "should skip classes that have already been evaluated" do
        @compile.catalog.stubs(:tag)

        @compile.expects(:class_scope).with(@class).returns("something")

        @compile.expects(:store_resource).never

        @resource.expects(:evaluate).never

        Puppet::Parser::Resource.expects(:new).never
        @compile.evaluate_classes(%w{myclass}, @scope, false)
    end

    it "should return the list of found classes" do
        @compile.catalog.stubs(:tag)

        @compile.stubs(:store_resource)
        @scope.stubs(:findclass).with("notfound").returns(nil)

        Puppet::Parser::Resource.stubs(:new).returns(@resource)
        @compile.evaluate_classes(%w{myclass notfound}, @scope).should == %w{myclass}
    end
end

describe Puppet::Parser::Compile, " when evaluating AST nodes with no AST nodes present" do
    include CompileTesting

    it "should do nothing" do
        @compile.expects(:ast_nodes?).returns(false)
        @compile.parser.expects(:nodes).never
        Puppet::Parser::Resource.expects(:new).never

        @compile.send(:evaluate_ast_node)
    end
end

describe Puppet::Parser::Compile, " when evaluating AST nodes with AST nodes present" do
    include CompileTesting

    before do
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

    it "should tag the catalog with the found node name" do
        node_class = stub 'node', :classname => "c"
        @nodes.stubs(:[]).with("c").returns(node_class)

        node_resource = stub 'node resource', :ref => "Node[c]", :evaluate => nil
        Puppet::Parser::Resource.stubs(:new).returns(node_resource)

        @compile.catalog.expects(:tag).with("c")
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

describe Puppet::Parser::Compile, " when initializing" do
    include CompileTesting

    it "should set its node attribute" do
        @compile.node.should equal(@node)
    end

    it "should set its parser attribute" do
        @compile.parser.should equal(@parser)
    end

    it "should detect when ast nodes are absent" do
        @compile.ast_nodes?.should be_false
    end

    it "should detect when ast nodes are present" do
        @parser.nodes["testing"] = "yay"
        @compile.ast_nodes?.should be_true
    end
end

describe Puppet::Parser::Compile do
    include CompileTesting

    it "should be able to store references to class scopes" do
        lambda { @compile.class_set "myname", "myscope" }.should_not raise_error
    end

    it "should be able to retrieve class scopes by name" do
        @compile.class_set "myname", "myscope"
        @compile.class_scope("myname").should == "myscope"
    end

    it "should be able to retrieve class scopes by object" do
        klass = mock 'ast_class'
        klass.expects(:classname).returns("myname")
        @compile.class_set "myname", "myscope"
        @compile.class_scope(klass).should == "myscope"
    end

    it "should be able to return a class list containing all set classes" do
        @compile.class_set "", "empty"
        @compile.class_set "one", "yep"
        @compile.class_set "two", "nope"

        @compile.classlist.sort.should == %w{one two}.sort
    end
end

describe Puppet::Parser::Compile, "when managing scopes" do
    include CompileTesting

    it "should create a top scope" do
        @compile.topscope.should be_instance_of(Puppet::Parser::Scope)
    end

    it "should be able to create new scopes" do
        @compile.newscope(@compile.topscope).should be_instance_of(Puppet::Parser::Scope)
    end

    it "should correctly set the level of newly created scopes" do
        @compile.newscope(@compile.topscope, :level => 5).level.should == 5
    end

    it "should set the parent scope of the new scope to be the passed-in parent" do
        scope = mock 'scope'
        newscope = @compile.newscope(scope)

        @compile.parent(newscope).should equal(scope)
    end
end

describe Puppet::Parser::Compile, "when storing compiled resources" do
    include CompileTesting

    it "should store the resources" do
        Puppet.features.expects(:rails?).returns(true)
        Puppet::Rails.expects(:connect)

        resource_table = mock 'resources'
        resource_table.expects(:values).returns(:resources)
        @compile.instance_variable_set("@resource_table", resource_table)
        @compile.expects(:store_to_active_record).with(@node, :resources)
        @compile.send(:store)
    end

    it "should store to active_record" do
        @node.expects(:name).returns("myname")
        Puppet::Rails::Host.stubs(:transaction).yields
        Puppet::Rails::Host.expects(:store).with(@node, :resources)
        @compile.send(:store_to_active_record, @node, :resources)
    end
end

describe Puppet::Parser::Compile, "when managing resource overrides" do
    include CompileTesting

    before do
        @override = stub 'override', :ref => "My[ref]"
        @resource = stub 'resource', :ref => "My[ref]", :builtin? => true
    end

    it "should be able to store overrides" do
        lambda { @compile.store_override(@override) }.should_not raise_error
    end

    it "should apply overrides to the appropriate resources" do
        @compile.store_resource(@scope, @resource)
        @resource.expects(:merge).with(@override)

        @compile.store_override(@override)

        @compile.compile
    end

    it "should accept overrides before the related resource has been created" do
        @resource.expects(:merge).with(@override)

        # First store the override
        @compile.store_override(@override)

        # Then the resource
        @compile.store_resource(@scope, @resource)

        # And compile, so they get resolved
        @compile.compile
    end

    it "should fail if the compile is finished and resource overrides have not been applied" do
        @compile.store_override(@override)

        lambda { @compile.compile }.should raise_error(Puppet::ParseError)
    end
end

# #620 - Nodes and classes should conflict, else classes don't get evaluated
describe Puppet::Parser::Compile, "when evaluating nodes and classes with the same name (#620)" do
    include CompileTesting

    before do
        @node = stub :nodescope? => true
        @class = stub :nodescope? => false
    end

    it "should fail if a node already exists with the same name as the class being evaluated" do
        @compile.class_set("one", @node)
        lambda { @compile.class_set("one", @class) }.should raise_error(Puppet::ParseError)
    end

    it "should fail if a class already exists with the same name as the node being evaluated" do
        @compile.class_set("one", @class)
        lambda { @compile.class_set("one", @node) }.should raise_error(Puppet::ParseError)
    end
end
