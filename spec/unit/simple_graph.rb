#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-1.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/simple_graph'

describe Puppet::SimpleGraph do
    it "should return the number of its vertices as its length" do
        @graph = Puppet::SimpleGraph.new
        @graph.add_vertex!("one")
        @graph.add_vertex!("two")
        @graph.size.should == 2
    end

    it "should consider itself a directed graph" do
        Puppet::SimpleGraph.new.directed?.should be_true
    end

    it "should provide a method for reversing the graph" do
        @graph = Puppet::SimpleGraph.new
        @graph.add_edge!(:one, :two)
        @graph.reversal.edge?(:two, :one).should be_true
    end

    it "should be able to produce a dot graph" do
        @graph = Puppet::SimpleGraph.new
        @graph.add_edge!(:one, :two)

        proc { @graph.to_dot_graph }.should_not raise_error
    end
end

describe Puppet::SimpleGraph, " when managing vertices" do
    before do
        @graph = Puppet::SimpleGraph.new
    end

    it "should provide a method to add a vertex" do
        @graph.add_vertex!(:test)
        @graph.vertex?(:test).should be_true
    end

    it "should ignore already-present vertices when asked to add a vertex" do
        @graph.add_vertex!(:test)
        proc { @graph.add_vertex!(:test) }.should_not raise_error
    end

    it "should return true when asked if a vertex is present" do
        @graph.add_vertex!(:test)
        @graph.vertex?(:test).should be_true
    end

    it "should return false when asked if a non-vertex is present" do
        @graph.vertex?(:test).should be_false
    end

    it "should return all set vertices when asked" do
        @graph.add_vertex!(:one)
        @graph.add_vertex!(:two)
        @graph.vertices.length.should == 2
        @graph.vertices.should include(:one)
        @graph.vertices.should include(:two)
    end

    it "should remove a given vertex when asked" do
        @graph.add_vertex!(:one)
        @graph.remove_vertex!(:one)
        @graph.vertex?(:one).should be_false
    end

    it "should do nothing when a non-vertex is asked to be removed" do
        proc { @graph.remove_vertex!(:one) }.should_not raise_error
    end
end

describe Puppet::SimpleGraph, " when managing edges" do
    before do
        @graph = Puppet::SimpleGraph.new
    end

    it "should provide a method to test whether a given vertex pair is an edge" do
        @graph.should respond_to(:edge?)
    end

    it "should provide a method to add an edge as an instance of the edge class" do
        edge = Puppet::Relationship.new(:one, :two)
        @graph.add_edge!(edge)
        @graph.edge?(:one, :two).should be_true
    end

    it "should provide a method to add an edge by specifying the two vertices" do
        @graph.add_edge!(:one, :two)
        @graph.edge?(:one, :two).should be_true
    end

    it "should provide a method to add an edge by specifying the two vertices and a label" do
        @graph.add_edge!(:one, :two, :stuff => :awesome)
        @graph.edge?(:one, :two).should be_true
    end

    it "should provide a method for retrieving an edge label" do
        edge = Puppet::Relationship.new(:one, :two, :stuff => :awesome)
        @graph.add_edge!(edge)
        @graph.edge_label(:one, :two).should == {:stuff => :awesome}
    end

    it "should provide a method for retrieving an edge" do
        edge = Puppet::Relationship.new(:one, :two)
        @graph.add_edge!(edge)
        @graph.edge(:one, :two).should equal(edge)
    end

    it "should add the edge source as a vertex if it is not already" do
        edge = Puppet::Relationship.new(:one, :two)
        @graph.add_edge!(edge)
        @graph.vertex?(:one).should be_true
    end

    it "should add the edge target as a vertex if it is not already" do
        edge = Puppet::Relationship.new(:one, :two)
        @graph.add_edge!(edge)
        @graph.vertex?(:two).should be_true
    end

    it "should return all edges as edge instances when asked" do
        one = Puppet::Relationship.new(:one, :two)
        two = Puppet::Relationship.new(:two, :three)
        @graph.add_edge!(one)
        @graph.add_edge!(two)
        edges = @graph.edges
        edges.length.should == 2
        edges.should include(one)
        edges.should include(two)
    end

    it "should remove an edge when asked" do
        edge = Puppet::Relationship.new(:one, :two)
        @graph.add_edge!(edge)
        @graph.remove_edge!(edge)
        @graph.edge?(edge.source, edge.target).should be_false
    end

    it "should remove all related edges when a vertex is removed" do
        one = Puppet::Relationship.new(:one, :two)
        two = Puppet::Relationship.new(:two, :three)
        @graph.add_edge!(one)
        @graph.add_edge!(two)
        @graph.remove_vertex!(:two)
        @graph.edge?(:one, :two).should be_false
        @graph.edge?(:two, :three).should be_false
        @graph.edges.length.should == 0
    end
end

describe Puppet::SimpleGraph, " when finding adjacent vertices" do
    before do
        @graph = Puppet::SimpleGraph.new
        @one_two = Puppet::Relationship.new(:one, :two)
        @two_three = Puppet::Relationship.new(:two, :three)
        @one_three = Puppet::Relationship.new(:one, :three)
        @graph.add_edge!(@one_two)
        @graph.add_edge!(@one_three)
        @graph.add_edge!(@two_three)
    end

    it "should return adjacent vertices" do
        adj = @graph.adjacent(:one)
        adj.should be_include(:three)
        adj.should be_include(:two)
    end

    it "should default to finding :out vertices" do
        @graph.adjacent(:two).should == [:three]
    end

    it "should support selecting :in vertices" do
        @graph.adjacent(:two, :direction => :in).should == [:one]
    end

    it "should default to returning the matching vertices as an array of vertices" do
        @graph.adjacent(:two).should == [:three]
    end

    it "should support returning an array of matching edges" do
        @graph.adjacent(:two, :type => :edges).should == [@two_three]
    end
end

describe Puppet::SimpleGraph, " when clearing" do
    before do
        @graph = Puppet::SimpleGraph.new
        one = Puppet::Relationship.new(:one, :two)
        two = Puppet::Relationship.new(:two, :three)
        @graph.add_edge!(one)
        @graph.add_edge!(two)

        @graph.clear
    end

    it "should remove all vertices" do
        @graph.vertices.should be_empty
    end

    it "should remove all edges" do
        @graph.edges.should be_empty
    end
end

describe Puppet::SimpleGraph, " when reversing graphs" do
    before do
        @graph = Puppet::SimpleGraph.new
    end

    it "should provide a method for reversing the graph" do
        @graph.add_edge!(:one, :two)
        @graph.reversal.edge?(:two, :one).should be_true
    end

    it "should add all vertices to the reversed graph" do
        @graph.add_edge!(:one, :two)
        @graph.vertex?(:one).should be_true
        @graph.vertex?(:two).should be_true
    end
    
    it "should retain labels on edges" do
        @graph.add_edge!(:one, :two, :stuff => :awesome)
        edge = @graph.reversal.edge(:two, :one)
        edge.label.should == {:stuff => :awesome}
    end
end

describe Puppet::SimpleGraph, " when sorting the graph" do
    before do
        @graph = Puppet::SimpleGraph.new
    end

    def add_edges(hash)
        hash.each do |a,b|
            @graph.add_edge!(a, b)
        end
    end

    it "should sort the graph topologically" do
        add_edges :a => :b, :b => :c
        @graph.topsort.should == [:a, :b, :c]
    end

    it "should fail on two-vertex loops" do
        add_edges :a => :b, :b => :a
        proc { @graph.topsort }.should raise_error(Puppet::Error)
    end

    it "should fail on multi-vertex loops" do
        add_edges :a => :b, :b => :c, :c => :a
        proc { @graph.topsort }.should raise_error(Puppet::Error)
    end

    it "should fail when a larger tree contains a small cycle" do
        add_edges :a => :b, :b => :a, :c => :a, :d => :c
        proc { @graph.topsort }.should raise_error(Puppet::Error)
    end

    it "should succeed on trees with no cycles" do
        add_edges :a => :b, :b => :e, :c => :a, :d => :c
        proc { @graph.topsort }.should_not raise_error
    end
end
