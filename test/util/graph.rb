#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-11-16.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/graph'
require 'puppet/util/graph'

class TestUtilGraph < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::Graph
    
	def test_to_graph
	    children = %w{a b c d}
        list = Container.new("yay", children)
        
        graph = nil
        assert_nothing_raised do
            graph = list.to_graph
        end
        
        assert(graph.vertices.include?(list), "wtf?")
        
        ([list] + children).each do |thing|
            assert(graph.vertex?(thing), "%s is not a vertex" % thing)
        end
        children.each do |child|
            assert(graph.edge?(list, child),
                "%s/%s was not added as an edge" % ["yay", child])
        end
    end
    
    def test_recursive_to_graph
        one, two, middle, top = build_tree
        
        graph = nil
        assert_nothing_raised do
            graph = top.to_graph
        end
        
        (%w{a b c d e f g h} + [one, two, middle, top]).each do |v|
            assert(graph.vertex?(v), "%s is not a vertex" % v)
        end
        
        [one, two, middle, top].each do |con|
            con.each do |child|
                assert(graph.edge?(con, child), "%s/%s is not an edge" % [con, child])
            end
        end
        
        # Now make sure we correctly retrieve the leaves from each container
        {top => %w{a b c d e f g h},
         one => %w{a b},
         two => %w{c d},
         middle => %w{c d e f}}.each do |cont, list|
            leaves = nil
            assert_nothing_raised do
                leaves = graph.leaves(cont)
            end
            leaves = leaves.sort
            assert_equal(list.sort, leaves.sort,
                "Got incorrect leaf list for %s" % cont.name)
            %w{a b c d e f g h}.each do |letter|
                unless list.include?(letter)
                    assert(!leaves.include?(letter),
                        "incorrectly got %s as a leaf of %s" %
                            [letter, cont.to_s])
                end
            end
        end
    end
    
    def test_to_graph_with_block
        middle = Container.new "middle", ["c", "d", 3, 4]
        top = Container.new "top", ["a", "b", middle, 1, 2]
        
        graph = nil
        assert_nothing_raised() { 
            graph = top.to_graph { |c| c.is_a?(String) or c.is_a?(Container) }
        }
        
        %w{a b c d}.each do |child|
            assert(graph.vertex?(child), "%s was not added as a vertex" % child)
        end
        
        [1, 2, 3, 4].each do |child|
            assert(! graph.vertex?(child), "%s is a vertex" % child)
        end
    end

    def test_cyclic_graphs
        one = Container.new "one", %w{a b}
        two = Container.new "two", %w{c d}
        
        one.push(two)
        two.push(one)
        
        assert_raise(Puppet::Error, "did not fail on cyclic graph") do
            one.to_graph
        end
    end
end

# $Id$
