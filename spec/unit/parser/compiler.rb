#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Compiler do
    before :each do
        @node = Puppet::Node.new "testnode"
        @parser = Puppet::Parser::Parser.new :environment => "development"

        @scope_resource = stub 'scope_resource', :builtin? => true, :finish => nil, :ref => 'Class[main]'
        @scope = stub 'scope', :resource => @scope_resource, :source => mock("source")
        @compiler = Puppet::Parser::Compiler.new(@node, @parser)
    end

    describe Puppet::Parser::Compiler do

        it "should be able to store references to class scopes" do
            lambda { @compiler.class_set "myname", "myscope" }.should_not raise_error
        end

        it "should be able to retrieve class scopes by name" do
            @compiler.class_set "myname", "myscope"
            @compiler.class_scope("myname").should == "myscope"
        end

        it "should be able to retrieve class scopes by object" do
            klass = mock 'ast_class'
            klass.expects(:classname).returns("myname")
            @compiler.class_set "myname", "myscope"
            @compiler.class_scope(klass).should == "myscope"
        end

        it "should be able to return a class list containing all set classes" do
            @compiler.class_set "", "empty"
            @compiler.class_set "one", "yep"
            @compiler.class_set "two", "nope"

            @compiler.classlist.sort.should == %w{one two}.sort
        end
    end

    describe Puppet::Parser::Compiler, " when initializing" do

        it "should set its node attribute" do
            @compiler.node.should equal(@node)
        end

        it "should set its parser attribute" do
            @compiler.parser.should equal(@parser)
        end

        it "should detect when ast nodes are absent" do
            @compiler.ast_nodes?.should be_false
        end

        it "should detect when ast nodes are present" do
            @parser.nodes["testing"] = "yay"
            @compiler.ast_nodes?.should be_true
        end
    end

    describe Puppet::Parser::Compiler, "when managing scopes" do

        it "should create a top scope" do
            @compiler.topscope.should be_instance_of(Puppet::Parser::Scope)
        end

        it "should be able to create new scopes" do
            @compiler.newscope(@compiler.topscope).should be_instance_of(Puppet::Parser::Scope)
        end

        it "should correctly set the level of newly created scopes" do
            @compiler.newscope(@compiler.topscope, :level => 5).level.should == 5
        end

        it "should set the parent scope of the new scope to be the passed-in parent" do
            scope = mock 'scope'
            newscope = @compiler.newscope(scope)

            @compiler.parent(newscope).should equal(scope)
        end
    end

    describe Puppet::Parser::Compiler, " when compiling" do

        def compile_methods
            [:set_node_parameters, :evaluate_main, :evaluate_ast_node, :evaluate_node_classes, :evaluate_generators, :fail_on_unevaluated,
                :finish, :store, :extract]
        end

        # Stub all of the main compile methods except the ones we're specifically interested in.
        def compile_stub(*except)
            (compile_methods - except).each { |m| @compiler.stubs(m) }
        end

        it "should set node parameters as variables in the top scope" do
            params = {"a" => "b", "c" => "d"}
            @node.stubs(:parameters).returns(params)
            compile_stub(:set_node_parameters)
            @compiler.compile
            @compiler.topscope.lookupvar("a").should == "b"
            @compiler.topscope.lookupvar("c").should == "d"
        end

        it "should evaluate any existing classes named in the node" do
            classes = %w{one two three four}
            main = stub 'main'
            one = stub 'one', :classname => "one"
            three = stub 'three', :classname => "three"
            @node.stubs(:name).returns("whatever")
            @node.stubs(:classes).returns(classes)

            @compiler.expects(:evaluate_classes).with(classes, @compiler.topscope)
            @compiler.class.publicize_methods(:evaluate_node_classes) { @compiler.evaluate_node_classes }
        end

        it "should enable ast_nodes if the parser has any nodes" do
            @parser.expects(:nodes).returns(:one => :yay)
            @compiler.ast_nodes?.should be_true
        end

        it "should disable ast_nodes if the parser has no nodes" do
            @parser.expects(:nodes).returns({})
            @compiler.ast_nodes?.should be_false
        end

        it "should evaluate the main class if it exists" do
            compile_stub(:evaluate_main)
            main_class = mock 'main_class'
            main_class.expects(:evaluate_code).with { |r| r.is_a?(Puppet::Parser::Resource) }
            @compiler.topscope.expects(:source=).with(main_class)
            @parser.stubs(:findclass).with("", "").returns(main_class)

            @compiler.compile
        end

        it "should evaluate any node classes" do
            @node.stubs(:classes).returns(%w{one two three four})
            @compiler.expects(:evaluate_classes).with(%w{one two three four}, @compiler.topscope)
            @compiler.send(:evaluate_node_classes)
        end

        it "should evaluate all added collections" do
            colls = []
            # And when the collections fail to evaluate.
            colls << mock("coll1-false")
            colls << mock("coll2-false")
            colls.each { |c| c.expects(:evaluate).returns(false) }

            @compiler.add_collection(colls[0])
            @compiler.add_collection(colls[1])

            compile_stub(:evaluate_generators)
            @compiler.compile
        end

        it "should ignore builtin resources" do
            resource = stub 'builtin', :ref => "File[testing]", :builtin? => true

            @compiler.add_resource(@scope, resource)
            resource.expects(:evaluate).never
        
            @compiler.compile
        end

        it "should evaluate unevaluated resources" do
            resource = stub 'notevaluated', :ref => "File[testing]", :builtin? => false, :evaluated? => false, :virtual? => false
            @compiler.add_resource(@scope, resource)

            # We have to now mark the resource as evaluated
            resource.expects(:evaluate).with { |*whatever| resource.stubs(:evaluated?).returns true }
        
            @compiler.compile
        end

        it "should not evaluate already-evaluated resources" do
            resource = stub 'already_evaluated', :ref => "File[testing]", :builtin? => false, :evaluated? => true, :virtual? => false
            @compiler.add_resource(@scope, resource)
            resource.expects(:evaluate).never
        
            @compiler.compile
        end

        it "should evaluate unevaluated resources created by evaluating other resources" do
            resource = stub 'notevaluated', :ref => "File[testing]", :builtin? => false, :evaluated? => false, :virtual? => false
            @compiler.add_resource(@scope, resource)

            resource2 = stub 'created', :ref => "File[other]", :builtin? => false, :evaluated? => false, :virtual? => false

            # We have to now mark the resource as evaluated
            resource.expects(:evaluate).with { |*whatever| resource.stubs(:evaluated?).returns(true); @compiler.add_resource(@scope, resource2) }
            resource2.expects(:evaluate).with { |*whatever| resource2.stubs(:evaluated?).returns(true) }

        
            @compiler.compile
        end

        it "should call finish() on all resources" do
            # Add a resource that does respond to :finish
            resource = Puppet::Parser::Resource.new :scope => @scope, :type => "file", :title => "finish"
            resource.expects(:finish)

            @compiler.add_resource(@scope, resource)

            # And one that does not
            dnf = stub "dnf", :ref => "File[dnf]"

            @compiler.add_resource(@scope, dnf)

            @compiler.send(:finish)
        end

        it "should add resources that do not conflict with existing resources" do
            resource = stub "noconflict", :ref => "File[yay]"
            @compiler.add_resource(@scope, resource)

            @compiler.catalog.should be_vertex(resource)
        end

        it "should fail to add resources that conflict with existing resources" do
            type = stub 'faketype', :isomorphic? => true, :name => "mytype"
            Puppet::Type.stubs(:type).with("mytype").returns(type)

            resource1 = stub "iso1conflict", :ref => "Mytype[yay]", :type => "mytype", :file => "eh", :line => 0
            resource2 = stub "iso2conflict", :ref => "Mytype[yay]", :type => "mytype", :file => "eh", :line => 0

            @compiler.add_resource(@scope, resource1)
            lambda { @compiler.add_resource(@scope, resource2) }.should raise_error(ArgumentError)
        end

        it "should have a method for looking up resources" do
            resource = stub 'resource', :ref => "Yay[foo]"
            @compiler.add_resource(@scope, resource)
            @compiler.findresource("Yay[foo]").should equal(resource)
        end

        it "should be able to look resources up by type and title" do
            resource = stub 'resource', :ref => "Yay[foo]"
            @compiler.add_resource(@scope, resource)
            @compiler.findresource("Yay", "foo").should equal(resource)
        end

        it "should not evaluate virtual defined resources" do
            resource = stub 'notevaluated', :ref => "File[testing]", :builtin? => false, :evaluated? => false, :virtual? => true
            @compiler.add_resource(@scope, resource)

            resource.expects(:evaluate).never
        
            @compiler.compile
        end
    end

    describe Puppet::Parser::Compiler, " when evaluating collections" do

        it "should evaluate each collection" do
            2.times { |i|
                coll = mock 'coll%s' % i
                @compiler.add_collection(coll)
            
                # This is the hard part -- we have to emulate the fact that
                # collections delete themselves if they are done evaluating.
                coll.expects(:evaluate).with do
                    @compiler.delete_collection(coll)
                end
            }

            @compiler.class.publicize_methods(:evaluate_collections) { @compiler.evaluate_collections }
        end

        it "should not fail when there are unevaluated resource collections that do not refer to specific resources" do
            coll = stub 'coll', :evaluate => false
            coll.expects(:resources).returns(nil)

            @compiler.add_collection(coll)

            lambda { @compiler.compile }.should_not raise_error
        end

        it "should fail when there are unevaluated resource collections that refer to a specific resource" do
            coll = stub 'coll', :evaluate => false
            coll.expects(:resources).returns(:something)

            @compiler.add_collection(coll)

            lambda { @compiler.compile }.should raise_error(Puppet::ParseError)
        end

        it "should fail when there are unevaluated resource collections that refer to multiple specific resources" do
            coll = stub 'coll', :evaluate => false
            coll.expects(:resources).returns([:one, :two])

            @compiler.add_collection(coll)

            lambda { @compiler.compile }.should raise_error(Puppet::ParseError)
        end
    end

    describe Puppet::Parser::Compiler, "when told to evaluate missing classes" do

        it "should fail if there's no source listed for the scope" do
            scope = stub 'scope', :source => nil
            proc { @compiler.evaluate_classes(%w{one two}, scope) }.should raise_error(Puppet::DevError)
        end

        it "should tag the catalog with the name of each not-found class" do
            @compiler.catalog.expects(:tag).with("notfound")
            @scope.expects(:findclass).with("notfound").returns(nil)
            @compiler.evaluate_classes(%w{notfound}, @scope)
        end
    end

    describe Puppet::Parser::Compiler, " when evaluating found classes" do

        before do
            @class = stub 'class', :classname => "my::class"
            @scope.stubs(:findclass).with("myclass").returns(@class)

            @resource = stub 'resource', :ref => "Class[myclass]"
        end

        it "should evaluate each class" do
            @compiler.catalog.stubs(:tag)

            @class.expects(:evaluate).with(@scope)

            @compiler.evaluate_classes(%w{myclass}, @scope)
        end

        it "should not evaluate the resources created for found classes unless asked" do
            @compiler.catalog.stubs(:tag)

            @resource.expects(:evaluate).never

            @class.expects(:evaluate).returns(@resource)

            @compiler.evaluate_classes(%w{myclass}, @scope)
        end

        it "should immediately evaluate the resources created for found classes when asked" do
            @compiler.catalog.stubs(:tag)

            @resource.expects(:evaluate)
            @class.expects(:evaluate).returns(@resource)

            @compiler.evaluate_classes(%w{myclass}, @scope, false)
        end

        it "should skip classes that have already been evaluated" do
            @compiler.catalog.stubs(:tag)

            @compiler.expects(:class_scope).with(@class).returns("something")

            @compiler.expects(:add_resource).never

            @resource.expects(:evaluate).never

            Puppet::Parser::Resource.expects(:new).never
            @compiler.evaluate_classes(%w{myclass}, @scope, false)
        end

        it "should return the list of found classes" do
            @compiler.catalog.stubs(:tag)

            @compiler.stubs(:add_resource)
            @scope.stubs(:findclass).with("notfound").returns(nil)

            Puppet::Parser::Resource.stubs(:new).returns(@resource)
            @class.stubs :evaluate
            @compiler.evaluate_classes(%w{myclass notfound}, @scope).should == %w{myclass}
        end
    end

    describe Puppet::Parser::Compiler, " when evaluating AST nodes with no AST nodes present" do

        it "should do nothing" do
            @compiler.expects(:ast_nodes?).returns(false)
            @compiler.parser.expects(:nodes).never
            Puppet::Parser::Resource.expects(:new).never

            @compiler.send(:evaluate_ast_node)
        end
    end

    describe Puppet::Parser::Compiler, " when evaluating AST nodes with AST nodes present" do

        before do
            @nodes = mock 'node_hash'
            @compiler.stubs(:ast_nodes?).returns(true)
            @compiler.parser.stubs(:nodes).returns(@nodes)

            # Set some names for our test
            @node.stubs(:names).returns(%w{a b c})
            @nodes.stubs(:[]).with("a").returns(nil)
            @nodes.stubs(:[]).with("b").returns(nil)
            @nodes.stubs(:[]).with("c").returns(nil)

            # It should check this last, of course.
            @nodes.stubs(:[]).with("default").returns(nil)
        end

        it "should fail if the named node cannot be found" do
            proc { @compiler.send(:evaluate_ast_node) }.should raise_error(Puppet::ParseError)
        end

        it "should evaluate the first node class matching the node name" do
            node_class = stub 'node', :classname => "c", :evaluate_code => nil
            @nodes.stubs(:[]).with("c").returns(node_class)

            node_resource = stub 'node resource', :ref => "Node[c]", :evaluate => nil
            node_class.expects(:evaluate).returns(node_resource)

            @compiler.compile
        end

        it "should match the default node if no matching node can be found" do
            node_class = stub 'node', :classname => "default", :evaluate_code => nil
            @nodes.stubs(:[]).with("default").returns(node_class)

            node_resource = stub 'node resource', :ref => "Node[default]", :evaluate => nil
            node_class.expects(:evaluate).returns(node_resource)

            @compiler.compile
        end

        it "should evaluate the node resource immediately rather than using lazy evaluation" do
            node_class = stub 'node', :classname => "c"
            @nodes.stubs(:[]).with("c").returns(node_class)

            node_resource = stub 'node resource', :ref => "Node[c]"
            node_class.expects(:evaluate).returns(node_resource)

            node_resource.expects(:evaluate)

            @compiler.send(:evaluate_ast_node)
        end

        it "should set the node's scope as the top scope" do
            node_resource = stub 'node resource', :ref => "Node[c]", :evaluate => nil
            node_class = stub 'node', :classname => "c", :evaluate => node_resource

            @nodes.stubs(:[]).with("c").returns(node_class)

            # The #evaluate method normally does this.
            scope = stub 'scope', :source => "mysource"
            @compiler.class_set(node_class.classname, scope)
            node_resource.stubs(:evaluate)

            @compiler.compile

            @compiler.topscope.should equal(scope)
        end
    end

    describe Puppet::Parser::Compiler, "when storing compiled resources" do

        it "should store the resources" do
            Puppet.features.expects(:rails?).returns(true)
            Puppet::Rails.expects(:connect)

            @compiler.catalog.expects(:vertices).returns(:resources)

            @compiler.expects(:store_to_active_record).with(@node, :resources)
            @compiler.send(:store)
        end

        it "should store to active_record" do
            @node.expects(:name).returns("myname")
            Puppet::Rails::Host.stubs(:transaction).yields
            Puppet::Rails::Host.expects(:store).with(@node, :resources)
            @compiler.send(:store_to_active_record, @node, :resources)
        end
    end

    describe Puppet::Parser::Compiler, "when managing resource overrides" do

        before do
            @override = stub 'override', :ref => "My[ref]"
            @resource = stub 'resource', :ref => "My[ref]", :builtin? => true
        end

        it "should be able to store overrides" do
            lambda { @compiler.add_override(@override) }.should_not raise_error
        end

        it "should apply overrides to the appropriate resources" do
            @compiler.add_resource(@scope, @resource)
            @resource.expects(:merge).with(@override)

            @compiler.add_override(@override)

            @compiler.compile
        end

        it "should accept overrides before the related resource has been created" do
            @resource.expects(:merge).with(@override)

            # First store the override
            @compiler.add_override(@override)

            # Then the resource
            @compiler.add_resource(@scope, @resource)

            # And compile, so they get resolved
            @compiler.compile
        end

        it "should fail if the compile is finished and resource overrides have not been applied" do
            @compiler.add_override(@override)

            lambda { @compiler.compile }.should raise_error(Puppet::ParseError)
        end
    end

    # #620 - Nodes and classes should conflict, else classes don't get evaluated
    describe Puppet::Parser::Compiler, "when evaluating nodes and classes with the same name (#620)" do

        before do
            @node = stub :nodescope? => true
            @class = stub :nodescope? => false
        end

        it "should fail if a node already exists with the same name as the class being evaluated" do
            @compiler.class_set("one", @node)
            lambda { @compiler.class_set("one", @class) }.should raise_error(Puppet::ParseError)
        end

        it "should fail if a class already exists with the same name as the node being evaluated" do
            @compiler.class_set("one", @class)
            lambda { @compiler.class_set("one", @node) }.should raise_error(Puppet::ParseError)
        end
    end
end
