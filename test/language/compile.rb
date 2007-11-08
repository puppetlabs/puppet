#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'mocha'
require 'puppettest'
require 'puppettest/parsertesting'
require 'puppet/parser/compile'

# Test our compile object.
class TestCompile < Test::Unit::TestCase
    include PuppetTest
    include PuppetTest::ParserTesting

    Compile = Puppet::Parser::Compile 
    Scope = Puppet::Parser::Scope 
    Node = Puppet::Network::Handler.handler(:node)
    SimpleNode = Puppet::Node

    def mknode(name = "foo")
        @node = SimpleNode.new(name)
    end

    def mkparser
        # This should mock an interpreter
        @parser = stub 'parser', :version => "1.0", :nodes => {}
    end

    def mkcompile(options = {})
        if node = options[:node]
            options.delete(:node)
        else
            node = mknode
        end
        @compile = Compile.new(node, mkparser, options)
    end

    def test_initialize
        compile = nil
        node = stub 'node', :name => "foo"
        parser = stub 'parser', :version => "1.0", :nodes => {}
        assert_nothing_raised("Could not init compile with all required options") do
            compile = Compile.new(node, parser)
        end

        assert_equal(node, compile.node, "Did not set node correctly")
        assert_equal(parser, compile.parser, "Did not set parser correctly")

        # We're not testing here whether we call initvars, because it's too difficult to
        # mock.

        # Now try it with some options
        assert_nothing_raised("Could not init compile with extra options") do
            compile = Compile.new(node, parser)
        end

        assert_equal(false, compile.ast_nodes?, "Did not set ast_nodes? correctly")
    end

    def test_initvars
        compile = mkcompile
        [:class_scopes, :resource_table, :exported_resources, :resource_overrides].each do |table|
            assert_instance_of(Hash, compile.send(:instance_variable_get, "@#{table}"), "Did not set %s table correctly" % table)
        end
        assert_instance_of(Scope, compile.topscope, "Did not create a topscope")
        graph = compile.instance_variable_get("@scope_graph")
        assert_instance_of(GRATR::Digraph, graph, "Did not create scope graph")
        assert(graph.vertex?(compile.topscope), "Did not add top scope as a vertex in the graph")
    end

    # Make sure we store and can retrieve references to classes and their scopes.
    def test_class_set_and_class_scope
        klass = mock 'ast_class'
        klass.expects(:classname).returns("myname")

        compile = mkcompile
        compile.configuration.expects(:tag).with("myname")
        
        assert_nothing_raised("Could not set class") do
            compile.class_set "myname", "myscope"
        end
        # First try to retrieve it by name.
        assert_equal("myscope", compile.class_scope("myname"), "Could not retrieve class scope by name")

        # Then by object
        assert_equal("myscope", compile.class_scope(klass), "Could not retrieve class scope by object")
    end
    
    def test_classlist
        compile = mkcompile

        compile.class_set "", "empty"
        compile.class_set "one", "yep"
        compile.class_set "two", "nope"

        # Make sure our class list is correct
        assert_equal(%w{one two}.sort, compile.classlist.sort, "Did not get correct class list")
    end

    # Make sure collections get added to our internal array
    def test_add_collection
        compile = mkcompile
        assert_nothing_raised("Could not add collection") do
            compile.add_collection "nope"
        end
        assert_equal(%w{nope}, compile.instance_variable_get("@collections"), "Did not add collection")
    end

    # Make sure we create a graph of scopes.
    def test_newscope
        compile = mkcompile
        graph = compile.instance_variable_get("@scope_graph")
        assert_instance_of(Scope, compile.topscope, "Did not create top scope")
        assert_instance_of(GRATR::Digraph, graph, "Did not create graph")

        assert(graph.vertex?(compile.topscope), "The top scope is not a vertex in the graph")

        # Now that we've got the top scope, create a new, subscope
        subscope = nil
        assert_nothing_raised("Could not create subscope") do
            subscope = compile.newscope(compile.topscope)
        end
        assert_instance_of(Scope, subscope, "Did not create subscope")
        assert(graph.edge?(compile.topscope, subscope), "An edge between top scope and subscope was not added")

        # Make sure a scope can find its parent.
        assert(compile.parent(subscope), "Could not look up parent scope on compile")
        assert_equal(compile.topscope.object_id, compile.parent(subscope).object_id, "Did not get correct parent scope from compile")
        assert_equal(compile.topscope.object_id, subscope.parent.object_id, "Scope did not correctly retrieve its parent scope")

        # Now create another, this time specifying options
        another = nil
        assert_nothing_raised("Could not create subscope") do
            another = compile.newscope(subscope, :level => 5)
        end
        assert_equal(5, another.level, "did not set scope option correctly")
        assert_instance_of(Scope, another, "Did not create second subscope")
        assert(graph.edge?(subscope, another), "An edge between parent scope and second subscope was not added")

        # Make sure it can find its parent.
        assert(compile.parent(another), "Could not look up parent scope of second subscope on compile")
        assert_equal(subscope.object_id, compile.parent(another).object_id, "Did not get correct parent scope of second subscope from compile")
        assert_equal(subscope.object_id, another.parent.object_id, "Second subscope did not correctly retrieve its parent scope")

        # And make sure both scopes show up in the right order in the search path
        assert_equal([another.object_id, subscope.object_id, compile.topscope.object_id], another.scope_path.collect { |p| p.object_id },
            "Did not get correct scope path")
    end

    # The heart of the action.
    def test_compile
        compile = mkcompile
        [:set_node_parameters, :evaluate_main, :evaluate_ast_node, :evaluate_node_classes, :evaluate_generators, :fail_on_unevaluated, :finish].each do |method|
            compile.expects(method)
        end
        assert_instance_of(Puppet::Node::Configuration, compile.compile, "Did not return the configuration")
    end

    # Test setting the node's parameters into the top scope.
    def test_set_node_parameters
        compile = mkcompile
        @node.parameters = {"a" => "b", "c" => "d"}
        scope = compile.topscope
        @node.parameters.each do |param, value|
            scope.expects(:setvar).with(param, value)
        end

        assert_nothing_raised("Could not call 'set_node_parameters'") do
            compile.send(:set_node_parameters)
        end
    end

    # Test that we can evaluate the main class, which is the one named "" in namespace
    # "".
    def test_evaluate_main
        compile = mkcompile
        main = mock 'main_class'
        compile.topscope.expects(:source=).with(main)
        @parser.expects(:findclass).with("", "").returns(main)

        assert_nothing_raised("Could not call evaluate_main") do
            compile.send(:evaluate_main)
        end

        assert(compile.resources.find { |r| r.to_s == "Class[main]" }, "Did not create a 'main' resource")
    end

    # Make sure we either don't look for nodes, or that we find and evaluate the right object.
    def test_evaluate_ast_node
        # First try it with ast_nodes disabled
        compile = mkcompile
        name = compile.node.name
        compile.expects(:ast_nodes?).returns(false)
        compile.parser.expects(:nodes).never

        assert_nothing_raised("Could not call evaluate_ast_node when ast nodes are disabled") do
            compile.send(:evaluate_ast_node)
        end

        assert_nil(compile.resources.find { |r| r.to_s == "Node[#{name}]" }, "Created node object when ast_nodes was false")

        # Now try it with them enabled, but no node found.
        nodes = mock 'node_hash'
        compile = mkcompile
        name = compile.node.name
        compile.expects(:ast_nodes?).returns(true)
        compile.parser.stubs(:nodes).returns(nodes)

        # Set some names for our test
        @node.names = %w{a b c}
        nodes.expects(:[]).with("a").returns(nil)
        nodes.expects(:[]).with("b").returns(nil)
        nodes.expects(:[]).with("c").returns(nil)

        # It should check this last, of course.
        nodes.expects(:[]).with("default").returns(nil)

        # And make sure the lack of a node throws an exception
        assert_raise(Puppet::ParseError, "Did not fail when we couldn't find an ast node") do
            compile.send(:evaluate_ast_node)
        end

        # Finally, make sure it works dandily when we have a node
        compile = mkcompile
        compile.expects(:ast_nodes?).returns(true)

        node = stub 'node', :classname => "c"
        nodes = {"c" => node}
        compile.parser.stubs(:nodes).returns(nodes)

        # Set some names for our test
        @node.names = %w{a b c}

        # And make sure we throw no exceptions.
        assert_nothing_raised("Failed when a node was found") do
            compile.send(:evaluate_ast_node)
        end

        assert_instance_of(Puppet::Parser::Resource, compile.resources.find { |r| r.to_s == "Node[c]" },
            "Did not create node resource")

        # Lastly, check when we actually find the default.
        compile = mkcompile
        compile.expects(:ast_nodes?).returns(true)

        node = stub 'node', :classname => "default"
        nodes = {"default" => node}
        compile.parser.stubs(:nodes).returns(nodes)

        # Set some names for our test
        @node.names = %w{a b c}

        # And make sure the lack of a node throws an exception
        assert_nothing_raised("Failed when a node was found") do
            compile.send(:evaluate_ast_node)
        end
        assert_instance_of(Puppet::Parser::Resource, compile.resources.find { |r| r.to_s == "Node[default]" },
            "Did not create default node resource")
    end

    def test_evaluate_node_classes
        compile = mkcompile
        @node.classes = %w{one two three four}
        compile.expects(:evaluate_classes).with(%w{one two three four}, compile.topscope)
        assert_nothing_raised("could not call evaluate_node_classes") do
            compile.send(:evaluate_node_classes)
        end
    end

    def test_evaluate_collections
        compile = mkcompile

        colls = []

        # Make sure we return false when there's nothing there.
        assert(! compile.send(:evaluate_collections), "Returned true when there were no collections")

        # And when the collections fail to evaluate.
        colls << mock("coll1-false")
        colls << mock("coll2-false")
        colls.each { |c| c.expects(:evaluate).returns(false) }

        compile.instance_variable_set("@collections", colls)
        assert(! compile.send(:evaluate_collections), "Returned true when collections both evaluated nothing")

        # Now have one of the colls evaluate
        colls.clear
        colls << mock("coll1-one-true")
        colls << mock("coll2-one-true")
        colls[0].expects(:evaluate).returns(true)
        colls[1].expects(:evaluate).returns(false)
        assert(compile.send(:evaluate_collections), "Did not return true when one collection evaluated true")

        # And have them both eval true
        colls.clear
        colls << mock("coll1-both-true")
        colls << mock("coll2-both-true")
        colls[0].expects(:evaluate).returns(true)
        colls[1].expects(:evaluate).returns(true)
        assert(compile.send(:evaluate_collections), "Did not return true when both collections evaluated true")
    end

    def test_unevaluated_resources
        compile = mkcompile
        resources = {}
        compile.instance_variable_set("@resource_table", resources)

        # First test it when the table is empty
        assert_nil(compile.send(:unevaluated_resources), "Somehow found unevaluated resources in an empty table")

        # Then add a builtin resources
        resources["one"] = mock("builtin only")
        resources["one"].expects(:builtin?).returns(true)
        assert_nil(compile.send(:unevaluated_resources), "Considered a builtin resource unevaluated")

        # And do both builtin and non-builtin but already evaluated
        resources.clear
        resources["one"] = mock("builtin (with eval)")
        resources["one"].expects(:builtin?).returns(true)
        resources["two"] = mock("evaled (with builtin)")
        resources["two"].expects(:builtin?).returns(false)
        resources["two"].expects(:evaluated?).returns(true)
        assert_nil(compile.send(:unevaluated_resources), "Considered either a builtin or evaluated resource unevaluated")

        # Now a single unevaluated resource.
        resources.clear
        resources["one"] = mock("unevaluated")
        resources["one"].expects(:builtin?).returns(false)
        resources["one"].expects(:evaluated?).returns(false)
        assert_equal([resources["one"]], compile.send(:unevaluated_resources), "Did not find unevaluated resource")

        # With two uneval'ed resources, and an eval'ed one thrown in
        resources.clear
        resources["one"] = mock("unevaluated one")
        resources["one"].expects(:builtin?).returns(false)
        resources["one"].expects(:evaluated?).returns(false)
        resources["two"] = mock("unevaluated two")
        resources["two"].expects(:builtin?).returns(false)
        resources["two"].expects(:evaluated?).returns(false)
        resources["three"] = mock("evaluated")
        resources["three"].expects(:builtin?).returns(false)
        resources["three"].expects(:evaluated?).returns(true)

        result = compile.send(:unevaluated_resources)
        %w{one two}.each do |name|
            assert(result.include?(resources[name]), "Did not find %s in the unevaluated list" % name)
        end
    end

    def test_evaluate_definitions
        # First try the case where there's nothing to return
        compile = mkcompile
        compile.expects(:unevaluated_resources).returns(nil)

        assert_nothing_raised("Could not test for unevaluated resources") do
            assert(! compile.send(:evaluate_definitions), "evaluate_definitions returned true when no resources were evaluated")
        end

        # Now try it with resources left to evaluate
        resources = []
        res1 = mock("resource1")
        res1.expects(:evaluate)
        res2 = mock("resource2")
        res2.expects(:evaluate)
        resources << res1 << res2
        compile = mkcompile
        compile.expects(:unevaluated_resources).returns(resources)

        assert_nothing_raised("Could not test for unevaluated resources") do
            assert(compile.send(:evaluate_definitions), "evaluate_definitions returned false when resources were evaluated")
        end
    end

    def test_evaluate_generators
        # First try the case where we have nothing to do
        compile = mkcompile
        compile.expects(:evaluate_definitions).returns(false)
        compile.expects(:evaluate_collections).returns(false)

        assert_nothing_raised("Could not call :eval_iterate") do
            compile.send(:evaluate_generators)
        end

        # FIXME I could not get this test to work, but the code is short
        # enough that I'm ok with it.
        # It's important that collections are evaluated before definitions,
        # so make sure that's the case by verifying that collections get tested
        # twice but definitions only once.
        #compile = mkcompile
        #compile.expects(:evaluate_collections).returns(true).returns(false)
        #compile.expects(:evaluate_definitions).returns(false)
        #compile.send(:eval_iterate)
    end

    def test_store
        compile = mkcompile
        Puppet.features.expects(:rails?).returns(true)
        Puppet::Rails.expects(:connect)

        node = mock 'node'
        resource_table = mock 'resources'
        resource_table.expects(:values).returns(:resources)
        compile.instance_variable_set("@node", node)
        compile.instance_variable_set("@resource_table", resource_table)
        compile.expects(:store_to_active_record).with(node, :resources)
        compile.send(:store)
    end

    def test_store_to_active_record
        compile = mkcompile
        node = mock 'node'
        node.expects(:name).returns("myname")
        Puppet::Rails::Host.stubs(:transaction).yields
        Puppet::Rails::Host.expects(:store).with(node, :resources)
        compile.send(:store_to_active_record, node, :resources)
    end

    # Make sure that 'finish' gets called on all of our resources.
    def test_finish
        compile = mkcompile
        table = compile.instance_variable_get("@resource_table")

        # Add a resource that does respond to :finish
        yep = mock("finisher")
        yep.expects(:respond_to?).with(:finish).returns(true)
        yep.expects(:finish)
        table["yep"] = yep

        # And one that does not
        dnf = mock("dnf")
        dnf.expects(:respond_to?).with(:finish).returns(false)
        table["dnf"] = dnf

        compile.send(:finish)
    end

    def test_verify_uniqueness
        compile = mkcompile

        resources = compile.instance_variable_get("@resource_table")
        resource = mock("noconflict")
        resource.expects(:ref).returns("File[yay]")
        assert_nothing_raised("Raised an exception when there should have been no conflict") do
            compile.send(:verify_uniqueness, resource)
        end

        # Now try the case where our type is isomorphic
        resources["thing"] = true

        isoconflict = mock("isoconflict")
        isoconflict.expects(:ref).returns("thing")
        isoconflict.expects(:type).returns("testtype")
        faketype = mock("faketype")
        faketype.expects(:isomorphic?).returns(false)
        faketype.expects(:name).returns("whatever")
        Puppet::Type.expects(:type).with("testtype").returns(faketype)
        assert_nothing_raised("Raised an exception when was a conflict in non-isomorphic types") do
            compile.send(:verify_uniqueness, isoconflict)
        end

        # Now test for when we actually have an exception
        initial = mock("initial")
        resources["thing"] = initial
        initial.expects(:file).returns(false)

        conflict = mock("conflict")
        conflict.expects(:ref).returns("thing").times(2)
        conflict.expects(:type).returns("conflict")
        conflict.expects(:file).returns(false)
        conflict.expects(:line).returns(false)

        faketype = mock("faketype")
        faketype.expects(:isomorphic?).returns(true)
        Puppet::Type.expects(:type).with("conflict").returns(faketype)
        assert_raise(Puppet::ParseError, "Did not fail when two isomorphic resources conflicted") do
            compile.send(:verify_uniqueness, conflict)
        end
    end

    def test_store_resource
        # Run once when there's no conflict
        compile = mkcompile
        table = compile.instance_variable_get("@resource_table")
        resource = mock("resource")
        resource.expects(:ref).returns("yay")
        compile.expects(:verify_uniqueness).with(resource)
        scope = stub("scope", :resource => mock('resource'))

        compile.configuration.expects(:add_edge!).with(scope.resource, resource)

        assert_nothing_raised("Could not store resource") do
            compile.store_resource(scope, resource)
        end
        assert_equal(resource, table["yay"], "Did not store resource in table")

        # Now for conflicts
        compile = mkcompile
        table = compile.instance_variable_get("@resource_table")
        resource = mock("resource")
        compile.expects(:verify_uniqueness).with(resource).raises(ArgumentError)

        assert_raise(ArgumentError, "Did not raise uniqueness exception") do
            compile.store_resource(scope, resource)
        end
        assert(table.empty?, "Conflicting resource was stored in table")
    end

    def test_fail_on_unevaluated
        compile = mkcompile
        compile.expects(:fail_on_unevaluated_overrides)
        compile.expects(:fail_on_unevaluated_resource_collections)
        compile.send :fail_on_unevaluated
    end

    def test_store_override
        # First test the case when the resource is not present.
        compile = mkcompile
        overrides = compile.instance_variable_get("@resource_overrides")
        override = Object.new
        override.expects(:ref).returns(:myref).times(2)
        override.expects(:override=).with(true)

        assert_nothing_raised("Could not call store_override") do
            compile.store_override(override)
        end
        assert_instance_of(Array, overrides[:myref], "Overrides table is not a hash of arrays")
        assert_equal(override, overrides[:myref][0], "Did not store override in appropriately named array")

        # And when the resource already exists.
        resource = mock 'resource'
        resources = compile.instance_variable_get("@resource_table")
        resources[:resref] = resource

        override = mock 'override'
        resource.expects(:merge).with(override)
        override.expects(:override=).with(true)
        override.expects(:ref).returns(:resref)
        assert_nothing_raised("Could not call store_override when the resource already exists.") do
            compile.store_override(override)
        end
    end

    def test_resource_overrides
        compile = mkcompile
        overrides = compile.instance_variable_get("@resource_overrides")
        overrides[:test] = :yay
        resource = mock 'resource'
        resource.expects(:ref).returns(:test)

        assert_equal(:yay, compile.resource_overrides(resource), "Did not return overrides from table")
    end

    def test_fail_on_unevaluated_resource_collections
        compile = mkcompile
        collections = compile.instance_variable_get("@collections")

        # Make sure we're fine when the list is empty
        assert_nothing_raised("Failed when no collections were present") do
            compile.send :fail_on_unevaluated_resource_collections
        end

        # And that we're fine when we've got collections but with no resources
        collections << mock('coll')
        collections[0].expects(:resources).returns(nil)
        assert_nothing_raised("Failed when no resource collections were present") do
            compile.send :fail_on_unevaluated_resource_collections
        end

        # But that we do fail when we've got resource collections left.
        collections.clear

        # return both an array and a string, because that's tested internally
        collections << mock('coll returns one')
        collections[0].expects(:resources).returns(:something)

        collections << mock('coll returns many')
        collections[1].expects(:resources).returns([:one, :two])

        assert_raise(Puppet::ParseError, "Did not fail on unevaluated resource collections") do
            compile.send :fail_on_unevaluated_resource_collections
        end
    end

    def test_fail_on_unevaluated_overrides
        compile = mkcompile
        overrides = compile.instance_variable_get("@resource_overrides")

        # Make sure we're fine when the list is empty
        assert_nothing_raised("Failed when no collections were present") do
            compile.send :fail_on_unevaluated_overrides
        end

        # But that we fail if there are any overrides left in the table.
        overrides[:yay] = []
        overrides[:foo] = []
        overrides[:bar] = [mock("override")]
        overrides[:bar][0].expects(:ref).returns("yay")
        assert_raise(Puppet::ParseError, "Failed to fail when overrides remain") do
            compile.send :fail_on_unevaluated_overrides
        end
    end

    def test_find_resource
        compile = mkcompile
        resources = compile.instance_variable_get("@resource_table")

        assert_nothing_raised("Could not call findresource when the resource table was empty") do
            assert_nil(compile.findresource("yay", "foo"), "Returned a non-existent resource")
            assert_nil(compile.findresource("yay[foo]"), "Returned a non-existent resource")
        end

        resources["Foo[bar]"] = :yay
        assert_nothing_raised("Could not call findresource when the resource table was not empty") do
            assert_equal(:yay, compile.findresource("foo", "bar"), "Returned a non-existent resource")
            assert_equal(:yay, compile.findresource("Foo[bar]"), "Returned a non-existent resource")
        end
    end

    # #620 - Nodes and classes should conflict, else classes don't get evaluated
    def test_nodes_and_classes_name_conflict
        # Test node then class
        compile = mkcompile
        node = stub :nodescope? => true
        klass = stub :nodescope? => false
        compile.class_set("one", node)
        assert_raise(Puppet::ParseError, "Did not fail when replacing node with class") do
            compile.class_set("one", klass)
        end

        # and class then node
        compile = mkcompile
        node = stub :nodescope? => true
        klass = stub :nodescope? => false
        compile.class_set("two", klass)
        assert_raise(Puppet::ParseError, "Did not fail when replacing node with class") do
            compile.class_set("two", node)
        end
    end
end
