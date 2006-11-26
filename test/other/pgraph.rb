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
	
	def test_collect_targets
	    graph = Puppet::PGraph.new
	    
	    event = Puppet::Event.new(:source => "a", :event => :yay)
	    none = Puppet::Event.new(:source => "a", :event => :NONE)
	    
	    graph.add_edge!("a", "b", :event => :yay)
	    
	    # Try it for the trivial case of one target and a matching event
	    assert_equal(["b"], graph.collect_targets([event]))
	    
	    # Make sure we get nothing with a different event
	    assert_equal([], graph.collect_targets([none]))
	    
	    # Set up multiple targets and make sure we get them all back
	    graph.add_edge!("a", "c", :event => :yay)
	    assert_equal(["b", "c"].sort, graph.collect_targets([event]).sort)
	    assert_equal([], graph.collect_targets([none]))
    end
    
    def test_dependencies
        graph = Puppet::PGraph.new
        
        graph.add_edge!("a", "b")
        graph.add_edge!("a", "c")
        graph.add_edge!("b", "d")
        
        assert_equal(%w{b c d}.sort, graph.dependencies("a").sort)
        assert_equal(%w{d}.sort, graph.dependencies("b").sort)
        assert_equal([].sort, graph.dependencies("c").sort)
    end
    
    # Test that we can take a containment graph and rearrange it by dependencies
    def test_splice
        one, two, middle, top = build_tree
        contgraph = top.to_graph
        
        # Now make a dependency graph
        deps = Puppet::PGraph.new
        
        contgraph.vertices.each do |v|
            deps.add_vertex(v)
        end
        
        {one => two, "f" => "c", "h" => middle}.each do |source, target|
            deps.add_edge!(source, target)
        end
        
        deps.to_jpg("deps-before")
        
        deps.splice!(contgraph, Container)
        
        assert(! deps.cyclic?, "Created a cyclic graph")
        
        nons = deps.vertices.find_all { |v| ! v.is_a?(String) }
        assert(nons.empty?,
            "still contain non-strings %s" % nons.inspect)
        
        deps.to_jpg("deps-after")
    end
end

# $Id$