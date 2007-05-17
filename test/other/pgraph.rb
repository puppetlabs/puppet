#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-11-16.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/graph'

class TestPGraph < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::Graph
	
	Edge = Puppet::Relationship
	
	def test_clear
	    graph = Puppet::PGraph.new
	    graph.add_edge!("a", "b")
	    graph.add_vertex! "c"
	    assert_nothing_raised do
	        graph.clear
        end
        assert(graph.vertices.empty?, "Still have vertices after clear")
        assert(graph.edges.empty?, "still have edges after clear")
    end
	    
	
	def test_matching_edges
	    graph = Puppet::PGraph.new
	    
	    event = Puppet::Event.new(:source => "a", :event => :yay)
	    none = Puppet::Event.new(:source => "a", :event => :NONE)
	    
	    edges = {}
	    
	    edges["a/b"] = Edge["a", "b", {:event => :yay, :callback => :refresh}]
	    edges["a/c"] = Edge["a", "c", {:event => :yay, :callback => :refresh}]
	    
	    graph.add_edge!(edges["a/b"])
	    
	    # Try it for the trivial case of one target and a matching event
	    assert_equal([edges["a/b"]], graph.matching_edges([event]))
	    
	    # Make sure we get nothing with a different event
	    assert_equal([], graph.matching_edges([none]))
	    
	    # Set up multiple targets and make sure we get them all back
	    graph.add_edge!(edges["a/c"])
	    assert_equal([edges["a/b"], edges["a/c"]].sort, graph.matching_edges([event]).sort)
	    assert_equal([], graph.matching_edges([none]))
    end
    
    def test_dependencies
        graph = Puppet::PGraph.new
        
        graph.add_edge!("a", "b")
        graph.add_edge!("a", "c")
        graph.add_edge!("b", "d")
        
        assert_equal(%w{b c d}.sort, graph.dependents("a").sort)
        assert_equal(%w{d}.sort, graph.dependents("b").sort)
        assert_equal([].sort, graph.dependents("c").sort)
        
        assert_equal(%w{a b}, graph.dependencies("d").sort)
        assert_equal(%w{a}, graph.dependencies("b").sort)
        assert_equal(%w{a}, graph.dependencies("c").sort)
        assert_equal([], graph.dependencies("a").sort)
        
    end
    
    # Test that we can take a containment graph and rearrange it by dependencies
    def test_splice
        one, two, three, middle, top = build_tree
        empty = Container.new("empty", [])
        # Also, add an empty container to top
        top.push empty

        contgraph = top.to_graph

        # Now add a couple of child files, so that we can test whether all
        # containers get spliced, rather than just components.

        # Now make a dependency graph
        deps = Puppet::PGraph.new

        contgraph.vertices.each do |v|
            deps.add_vertex(v)
        end

        # We have to specify a relationship to our empty container, else it
        # never makes it into the dep graph in the first place.
        {one => two, "f" => "c", "h" => middle, "c" => empty}.each do |source, target|
            deps.add_edge!(source, target, :callback => :refresh)
        end
        
        #contgraph.to_jpg(File.expand_path("~/Desktop/pics"), "main")
        #deps.to_jpg(File.expand_path("~/Desktop/pics"), "before")
        assert_nothing_raised { deps.splice!(contgraph, Container) }
        
        assert(! deps.cyclic?, "Created a cyclic graph")

        # Make sure there are no container objects remaining
        #deps.to_jpg(File.expand_path("~/Desktop/pics"), "after")
        c = deps.vertices.find_all { |v| v.is_a?(Container) }
        assert(c.empty?, "Still have containers %s" % c.inspect)
        
        # Now make sure the containers got spliced correctly.
        contgraph.leaves(middle).each do |leaf|
            assert(deps.edge?("h", leaf), "no edge for h => %s" % leaf)
        end
        one.each do |oobj|
            two.each do |tobj|
                assert(deps.edge?(oobj, tobj), "no %s => %s edge" % [oobj, tobj])
            end
        end
        
        nons = deps.vertices.find_all { |v| ! v.is_a?(String) }
        assert(nons.empty?,
            "still contain non-strings %s" % nons.inspect)
        
        deps.edges.each do |edge|
            assert_equal({:callback => :refresh}, edge.label,
                "Label was not copied for %s => %s" % [edge.source, edge.target])
        end

        # Now add some relationships to three, but only add labels to one of
        # the relationships.

        # Add a simple, label-less relationship
        deps.add_edge!(two, three)
        assert_nothing_raised { deps.splice!(contgraph, Container) }

        # And make sure it stuck, with no labels.
        assert_equal({}, deps.edge_label("c", "i"),
            "label was created for c => i")

        # Now add some edges with labels, in a way that should overwrite
        deps.add_edge!("c", three, {:callback => :refresh})
        assert_nothing_raised { deps.splice!(contgraph, Container) }

        # And make sure the label got copied.
        assert_equal({:callback => :refresh}, deps.edge_label("c", "i"),
            "label was not copied for c => i")

        # Lastly, add some new label-less edges and make sure the label stays.
        deps.add_edge!(middle, three)
        assert_nothing_raised { deps.splice!(contgraph, Container) }
        assert_equal({:callback => :refresh}, deps.edge_label("c", "i"),
            "label was lost for c => i")
        
        # Now make sure the 'three' edges all have the label we've used.
        # Note that this will not work when we support more than one type of
        # subscription.
        three.each do |child|
            edge = deps.edge_class.new("c", child)
            assert(deps.edge?(edge), "no c => %s edge" % child)
            assert_equal({:callback => :refresh}, deps[edge],
                "label was not retained for c => %s" % child)
        end
    end

    def test_copy_label
        graph = Puppet::PGraph.new

        # First make an edge with no label
        graph.add_edge!(:a, :b)
        assert_nil(graph.edge_label(:a, :b), "Created a label")

        # Now try to copy an empty label in.
        graph.copy_label(:a, :b, {})

        # It should just do nothing, since we copied an empty label.
        assert_nil(graph.edge_label(:a, :b), "Created a label")

        # Now copy in a real label.
        graph.copy_label(:a, :b, {:callback => :yay})
        assert_equal({:callback => :yay},
            graph.edge_label(:a, :b), "Did not copy label")

        # Now copy in a nil label
        graph.copy_label(:a, :b, nil)
        assert_equal({:callback => :yay},
            graph.edge_label(:a, :b), "lost label")

        # And an empty one.
        graph.copy_label(:a, :b, {})
        assert_equal({:callback => :yay},
            graph.edge_label(:a, :b), "lost label")
    end

    def test_fail_on_cycle
        {
            {:a => :b, :b => :a, :c => :a, :d => :c} => true, # larger tree involving a smaller cycle
            {:a => :b, :b => :c, :c => :a} => true,
            {:a => :b, :b => :a, :c => :d, :d => :c} => true,
            {:a => :b, :b => :c} => false,
        }.each do |hash, result|
            graph = Puppet::PGraph.new
            hash.each do |a,b|
                graph.add_edge!(a, b)
            end

            if result
                assert_raise(Puppet::Error, "%s did not fail" % hash.inspect) do
                   graph.topsort
                end
            else
                assert_nothing_raised("%s failed" % hash.inspect) do
                    graph.topsort
                end
            end
        end
    end

    # This isn't really a unit test, it's just a way to do some graphing with
    # tons of relationships so we can see how it performs.
    def disabled_test_lots_of_relationships
        containers = Puppet::PGraph.new
        relationships = Puppet::PGraph.new
        labels = %w{a b c d e}
        conts = {}
        vertices = {}
        labels.each do |label|
            vertices[label] = []
        end
        num = 100
        num.times do |i|
            labels.each do |label|
                vertices[label] << ("%s%s" % [label, i])
            end
        end
        labels.each do |label|
            conts[label] = Container.new(label, vertices[label])
        end

        conts.each do |label, cont|
            cont.each do |child|
                containers.add_edge!(cont, child)
            end
        end
        prev = nil
        labels.inject(nil) do |prev, label|
            if prev
                containers.add_edge!(conts[prev], conts[label])
            end
            label
        end

        containers.to_jpg(File.expand_path("~/Desktop/pics/lots"), "start")

        # Now create the relationship graph

        # Make everything in both b and c require d1
        %w{b c}.each do |label|
            conts[label].each do |v|
                relationships.add_edge!(v, "d1")
                #relationships.add_edge!(v, conts["d"])
            end
        end

        # Make most in b also require the appropriate thing in c
        conts["b"].each do |v|
            i = v.split('')[1]

            relationships.add_edge!(v, "c%s" % i)
        end

        # And make d1 require most of e
        num.times do |i|
            relationships.add_edge!("d1", "e%s" % i)
        end

        containers.vertices.each do |v|
            relationships.add_vertex!(v)
        end
        relationships.to_jpg(File.expand_path("~/Desktop/pics/lots"), "relationships")

        time = Benchmark.realtime do
            relationships.splice!(containers, Container)
        end
        relationships.to_jpg(File.expand_path("~/Desktop/pics/lots"), "final")
        puts time
        time = Benchmark.realtime do
            relationships.topsort
        end
    end
end

# $Id$
