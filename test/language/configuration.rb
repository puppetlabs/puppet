#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'mocha'
require 'puppettest'
require 'puppettest/parsertesting'
require 'puppet/parser/configuration'

# Test our configuration object.
class TestConfiguration < Test::Unit::TestCase
    include PuppetTest
    include PuppetTest::ParserTesting

    Config = Puppet::Parser::Configuration 
    Scope = Puppet::Parser::Scope 

    def mkconfig
        Config.new(:host => "foo", :interpreter => "interp")
    end

    def test_initialize
        # Make sure we get an error if we don't send an interpreter
        assert_raise(ArgumentError, "Did not fail when missing host") do
            Config.new(:interpreter => "yay" )
        end
        assert_raise(ArgumentError, "Did not fail when missing interp") do
            Config.new(:host => "foo")
        end

        # Now check the defaults
        config = nil
        assert_nothing_raised("Could not init config with all required options") do
            config = Config.new(:host => "foo", :interpreter => "interp")
        end

        assert_equal("foo", config.host, "Did not set host correctly")
        assert_equal("interp", config.interpreter, "Did not set interpreter correctly")
        assert_equal({}, config.facts, "Did not set default facts")

        # Now make a new one with facts, to make sure the facts get set appropriately
        assert_nothing_raised("Could not init config with all required options") do
            config = Config.new(:host => "foo", :interpreter => "interp", :facts => {"a" => "b"})
        end
        assert_equal({"a" => "b"}, config.facts, "Did not set facts")
    end

    def test_initvars
        config = mkconfig
        [:class_scopes, :resource_table, :exported_resources, :resource_overrides].each do |table|
            assert_instance_of(Hash, config.send(:instance_variable_get, "@#{table}"), "Did not set %s table correctly" % table)
        end
    end

    # Make sure we store and can retrieve references to classes and their scopes.
    def test_class_set_and_class_scope
        klass = Object.new
        klass.expects(:classname).returns("myname")

        config = mkconfig
        
        assert_nothing_raised("Could not set class") do
            config.class_set "myname", "myscope"
        end
        # First try to retrieve it by name.
        assert_equal("myscope", config.class_scope("myname"), "Could not retrieve class scope by name")

        # Then by object
        assert_equal("myscope", config.class_scope(klass), "Could not retrieve class scope by object")
    end
    
    def test_classlist
        config = mkconfig

        config.class_set "", "empty"
        config.class_set "one", "yep"
        config.class_set "two", "nope"

        # Make sure our class list is correct
        assert_equal(%w{one two}.sort, config.classlist.sort, "Did not get correct class list")
    end

    # Make sure collections get added to our internal array
    def test_add_collection
        config = mkconfig
        assert_nothing_raised("Could not add collection") do
            config.add_collection "nope"
        end
        assert_equal(%w{nope}, config.instance_variable_get("@collections"), "Did not add collection")
    end

    # Make sure we create a graph of scopes.
    def test_newscope
        config = mkconfig
        graph = config.instance_variable_get("@graph")
        assert_instance_of(Scope, config.topscope, "Did not create top scope")
        assert_instance_of(GRATR::Digraph, graph, "Did not create graph")

        assert(graph.vertex?(config.topscope), "The top scope is not a vertex in the graph")

        # Now that we've got the top scope, create a new, subscope
        subscope = nil
        assert_nothing_raised("Could not create subscope") do
            subscope = config.newscope
        end
        assert_instance_of(Scope, subscope, "Did not create subscope")
        assert(graph.edge?(config.topscope, subscope), "An edge between top scope and subscope was not added")

        # Make sure a scope can find its parent.
        assert(config.parent(subscope), "Could not look up parent scope on configuration")
        assert_equal(config.topscope.object_id, config.parent(subscope).object_id, "Did not get correct parent scope from configuration")
        assert_equal(config.topscope.object_id, subscope.parent.object_id, "Scope did not correctly retrieve its parent scope")

        # Now create another, this time specifying the parent scope
        another = nil
        assert_nothing_raised("Could not create subscope") do
            another = config.newscope(subscope)
        end
        assert_instance_of(Scope, another, "Did not create second subscope")
        assert(graph.edge?(subscope, another), "An edge between parent scope and second subscope was not added")

        # Make sure it can find its parent.
        assert(config.parent(another), "Could not look up parent scope of second subscope on configuration")
        assert_equal(subscope.object_id, config.parent(another).object_id, "Did not get correct parent scope of second subscope from configuration")
        assert_equal(subscope.object_id, another.parent.object_id, "Second subscope did not correctly retrieve its parent scope")

        # And make sure both scopes show up in the right order in the search path
        assert_equal([another.object_id, subscope.object_id, config.topscope.object_id], another.scope_path.collect { |p| p.object_id },
            "Did not get correct scope path")
    end
end
