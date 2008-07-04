#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-12.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/pgraph'
require 'puppet/util/graph'

class Container
    include Puppet::Util::Graph
    include Enumerable
    attr_accessor :name
    def each
        @children.each do |c| yield c end
    end
    
    def initialize(name, ary)
        @name = name
        @children = ary
    end
    
    def push(*ary)
        ary.each { |c| @children.push(c)}
    end
    
    def to_s
        @name
    end
end

describe Puppet::PGraph do
    before do
        @graph = Puppet::PGraph.new
    end

    it "should correctly clear vertices and edges when asked" do
	    @graph.add_edge("a", "b")
	    @graph.add_vertex "c"
        @graph.clear
        @graph.vertices.should be_empty
        @graph.edges.should be_empty
    end
end

describe Puppet::PGraph, " when matching edges" do
    before do
        @graph = Puppet::PGraph.new
	    @event = Puppet::Transaction::Event.new(:yay, "a")
	    @none = Puppet::Transaction::Event.new(:NONE, "a")

	    @edges = {}
	    @edges["a/b"] = Puppet::Relationship.new("a", "b", {:event => :yay, :callback => :refresh})
	    @edges["a/c"] = Puppet::Relationship.new("a", "c", {:event => :yay, :callback => :refresh})
	    @graph.add_edge(@edges["a/b"])
    end

    it "should match edges whose source matches the source of the event" do
	    @graph.matching_edges([@event]).should == [@edges["a/b"]]
    end

    it "should match always match nothing when the event is :NONE" do
	    @graph.matching_edges([@none]).should be_empty
    end

    it "should match multiple edges" do
	    @graph.add_edge(@edges["a/c"])
        edges = @graph.matching_edges([@event])
        edges.should be_include(@edges["a/b"])
        edges.should be_include(@edges["a/c"])
    end
end

describe Puppet::PGraph, " when determining dependencies" do
    before do
        @graph = Puppet::PGraph.new
        
        @graph.add_edge("a", "b")
        @graph.add_edge("a", "c")
        @graph.add_edge("b", "d")
    end

    it "should find all dependents when they are on multiple levels" do
        @graph.dependents("a").sort.should == %w{b c d}.sort
    end

    it "should find single dependents" do
        @graph.dependents("b").sort.should == %w{d}.sort
    end

    it "should return an empty array when there are no dependents" do
        @graph.dependents("c").sort.should == [].sort
    end

    it "should find all dependencies when they are on multiple levels" do
        @graph.dependencies("d").sort.should == %w{a b}
    end

    it "should find single dependencies" do
        @graph.dependencies("c").sort.should == %w{a}
    end
    
    it "should return an empty array when there are no dependencies" do
        @graph.dependencies("a").sort.should == []
    end
end

describe Puppet::PGraph, " when splicing the relationship graph" do
    def container_graph
        @one = Container.new("one", %w{a b})
        @two = Container.new("two", ["c", "d"])
        @three = Container.new("three", ["i", "j"])
        @middle = Container.new("middle", ["e", "f", @two])
        @top = Container.new("top", ["g", "h", @middle, @one, @three])
        @empty = Container.new("empty", [])

        @contgraph = @top.to_graph

        # We have to add the container to the main graph, else it won't
        # be spliced in the dependency graph.
        @contgraph.add_vertex(@empty)
    end

    def dependency_graph
        @depgraph = Puppet::PGraph.new
        @contgraph.vertices.each do |v|
            @depgraph.add_vertex(v)
        end

        # We have to specify a relationship to our empty container, else it
        # never makes it into the dep graph in the first place.
        {@one => @two, "f" => "c", "h" => @middle, "c" => @empty}.each do |source, target|
            @depgraph.add_edge(source, target, :callback => :refresh)
        end
    end

    def splice
        @depgraph.splice!(@contgraph, Container)
    end

    before do
        container_graph
        dependency_graph
        splice
    end

    # This is the real heart of splicing -- replacing all containers in
    # our relationship and exploding their relationships so that each
    # relationship to a container gets copied to all of its children.
    it "should remove all Container objects from the dependency graph" do
        @depgraph.vertices.find_all { |v| v.is_a?(Container) }.should be_empty
    end

    it "should add container relationships to contained objects" do
        @contgraph.leaves(@middle).each do |leaf|
            @depgraph.should be_edge("h", leaf)
        end
    end

    it "should explode container-to-container relationships, making edges between all respective contained objects" do
        @one.each do |oobj|
            @two.each do |tobj|
                @depgraph.should be_edge(oobj, tobj)
            end
        end
    end

    it "should no longer contain anything but the non-container objects" do
        @depgraph.vertices.find_all { |v| ! v.is_a?(String) }.should be_empty
    end

    it "should copy labels" do
        @depgraph.edges.each do |edge|
            edge.label.should == {:callback => :refresh}
        end
    end

    it "should not add labels to edges that have none" do
        @depgraph.add_edge(@two, @three)
        splice
        @depgraph.edge_label("c", "i").should == {}
    end

    it "should copy labels over edges that have none" do
        @depgraph.add_edge("c", @three, {:callback => :refresh})
        splice
        # And make sure the label got copied.
        @depgraph.edge_label("c", "i").should == {:callback => :refresh}
    end

    it "should not replace a label with a nil label" do
        # Lastly, add some new label-less edges and make sure the label stays.
        @depgraph.add_edge(@middle, @three)
        @depgraph.add_edge("c", @three, {:callback => :refresh})
        splice
        @depgraph.edge_label("c", "i").should == {:callback => :refresh}
    end

    it "should copy labels to all created edges" do
        @depgraph.add_edge(@middle, @three)
        @depgraph.add_edge("c", @three, {:callback => :refresh})
        splice
        @three.each do |child|
            edge = Puppet::Relationship.new("c", child)
            @depgraph.should be_edge(edge.source, edge.target)
            @depgraph.edge_label(edge.source, edge.target).should == {:callback => :refresh}
        end
    end
end
