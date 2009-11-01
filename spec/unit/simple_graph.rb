#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-1.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/simple_graph'

describe Puppet::SimpleGraph do
    it "should return the number of its vertices as its length" do
        @graph = Puppet::SimpleGraph.new
        @graph.add_vertex("one")
        @graph.add_vertex("two")
        @graph.size.should == 2
    end

    it "should consider itself a directed graph" do
        Puppet::SimpleGraph.new.directed?.should be_true
    end

    it "should provide a method for reversing the graph" do
        @graph = Puppet::SimpleGraph.new
        @graph.add_edge(:one, :two)
        @graph.reversal.edge?(:two, :one).should be_true
    end

    it "should be able to produce a dot graph" do
        @graph = Puppet::SimpleGraph.new
        @graph.add_edge(:one, :two)

        proc { @graph.to_dot_graph }.should_not raise_error
    end

    it "should always put its edges first when printing yaml" do
        @graph = Puppet::SimpleGraph.new
        @graph.add_edge(:one, :two)
        @graph.to_yaml_properties[0].should == "@edges"
    end

    describe "when managing vertices" do
        before do
            @graph = Puppet::SimpleGraph.new
        end

        it "should provide a method to add a vertex" do
            @graph.add_vertex(:test)
            @graph.vertex?(:test).should be_true
        end

        it "should reset its reversed graph when vertices are added" do
            rev = @graph.reversal
            @graph.add_vertex(:test)
            @graph.reversal.should_not equal(rev)
        end

        it "should ignore already-present vertices when asked to add a vertex" do
            @graph.add_vertex(:test)
            proc { @graph.add_vertex(:test) }.should_not raise_error
        end

        it "should return true when asked if a vertex is present" do
            @graph.add_vertex(:test)
            @graph.vertex?(:test).should be_true
        end

        it "should return false when asked if a non-vertex is present" do
            @graph.vertex?(:test).should be_false
        end

        it "should return all set vertices when asked" do
            @graph.add_vertex(:one)
            @graph.add_vertex(:two)
            @graph.vertices.length.should == 2
            @graph.vertices.should include(:one)
            @graph.vertices.should include(:two)
        end

        it "should remove a given vertex when asked" do
            @graph.add_vertex(:one)
            @graph.remove_vertex!(:one)
            @graph.vertex?(:one).should be_false
        end

        it "should do nothing when a non-vertex is asked to be removed" do
            proc { @graph.remove_vertex!(:one) }.should_not raise_error
        end
    end

    describe "when managing edges" do
        before do
            @graph = Puppet::SimpleGraph.new
        end

        it "should provide a method to test whether a given vertex pair is an edge" do
            @graph.should respond_to(:edge?)
        end

        it "should reset its reversed graph when edges are added" do
            rev = @graph.reversal
            @graph.add_edge(:one, :two)
            @graph.reversal.should_not equal(rev)
        end

        it "should provide a method to add an edge as an instance of the edge class" do
            edge = Puppet::Relationship.new(:one, :two)
            @graph.add_edge(edge)
            @graph.edge?(:one, :two).should be_true
        end

        it "should provide a method to add an edge by specifying the two vertices" do
            @graph.add_edge(:one, :two)
            @graph.edge?(:one, :two).should be_true
        end

        it "should provide a method to add an edge by specifying the two vertices and a label" do
            @graph.add_edge(:one, :two, :callback => :awesome)
            @graph.edge?(:one, :two).should be_true
        end

        it "should provide a method for retrieving an edge label" do
            edge = Puppet::Relationship.new(:one, :two, :callback => :awesome)
            @graph.add_edge(edge)
            @graph.edge_label(:one, :two).should == {:callback => :awesome}
        end

        it "should provide a method for retrieving an edge" do
            edge = Puppet::Relationship.new(:one, :two)
            @graph.add_edge(edge)
            @graph.edge(:one, :two).should equal(edge)
        end

        it "should add the edge source as a vertex if it is not already" do
            edge = Puppet::Relationship.new(:one, :two)
            @graph.add_edge(edge)
            @graph.vertex?(:one).should be_true
        end

        it "should add the edge target as a vertex if it is not already" do
            edge = Puppet::Relationship.new(:one, :two)
            @graph.add_edge(edge)
            @graph.vertex?(:two).should be_true
        end

        it "should return all edges as edge instances when asked" do
            one = Puppet::Relationship.new(:one, :two)
            two = Puppet::Relationship.new(:two, :three)
            @graph.add_edge(one)
            @graph.add_edge(two)
            edges = @graph.edges
            edges.should be_instance_of(Array)
            edges.length.should == 2
            edges.should include(one)
            edges.should include(two)
        end

        it "should remove an edge when asked" do
            edge = Puppet::Relationship.new(:one, :two)
            @graph.add_edge(edge)
            @graph.remove_edge!(edge)
            @graph.edge?(edge.source, edge.target).should be_false
        end

        it "should remove all related edges when a vertex is removed" do
            one = Puppet::Relationship.new(:one, :two)
            two = Puppet::Relationship.new(:two, :three)
            @graph.add_edge(one)
            @graph.add_edge(two)
            @graph.remove_vertex!(:two)
            @graph.edge?(:one, :two).should be_false
            @graph.edge?(:two, :three).should be_false
            @graph.edges.length.should == 0
        end
    end

    describe "when finding adjacent vertices" do
        before do
            @graph = Puppet::SimpleGraph.new
            @one_two = Puppet::Relationship.new(:one, :two)
            @two_three = Puppet::Relationship.new(:two, :three)
            @one_three = Puppet::Relationship.new(:one, :three)
            @graph.add_edge(@one_two)
            @graph.add_edge(@one_three)
            @graph.add_edge(@two_three)
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

        # Bug #2111
        it "should not consider a vertex adjacent just because it was asked about previously" do
            @graph = Puppet::SimpleGraph.new
            @graph.add_vertex("a")
            @graph.add_vertex("b")
            @graph.edge?("a", "b")
            @graph.adjacent("a").should == []
        end
    end

    describe "when clearing" do
        before do
            @graph = Puppet::SimpleGraph.new
            one = Puppet::Relationship.new(:one, :two)
            two = Puppet::Relationship.new(:two, :three)
            @graph.add_edge(one)
            @graph.add_edge(two)

            @graph.clear
        end

        it "should remove all vertices" do
            @graph.vertices.should be_empty
        end

        it "should remove all edges" do
            @graph.edges.should be_empty
        end
    end

    describe "when reversing graphs" do
        before do
            @graph = Puppet::SimpleGraph.new
        end

        it "should provide a method for reversing the graph" do
            @graph.add_edge(:one, :two)
            @graph.reversal.edge?(:two, :one).should be_true
        end

        it "should add all vertices to the reversed graph" do
            @graph.add_edge(:one, :two)
            @graph.vertex?(:one).should be_true
            @graph.vertex?(:two).should be_true
        end

        it "should retain labels on edges" do
            @graph.add_edge(:one, :two, :callback => :awesome)
            edge = @graph.reversal.edge(:two, :one)
            edge.label.should == {:callback => :awesome}
        end
    end

    describe "when sorting the graph" do
        before do
            @graph = Puppet::SimpleGraph.new
        end

        def add_edges(hash)
            hash.each do |a,b|
                @graph.add_edge(a, b)
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

        # Our graph's add_edge method is smart enough not to add
        # duplicate edges, so we use the objects, which it doesn't
        # check.
        it "should be able to sort graphs with duplicate edges" do
            one = Puppet::Relationship.new(:a, :b)
            @graph.add_edge(one)
            two = Puppet::Relationship.new(:a, :b)
            @graph.add_edge(two)
            proc { @graph.topsort }.should_not raise_error
        end
    end

    describe "when writing dot files" do
        before do
            @graph = Puppet::SimpleGraph.new
            @name = :test
            @file = File.join(Puppet[:graphdir], @name.to_s + ".dot")
        end

        it "should only write when graphing is enabled" do
            File.expects(:open).with(@file).never
            Puppet[:graph] = false
            @graph.write_graph(@name)
        end

        it "should write a dot file based on the passed name" do
            File.expects(:open).with(@file, "w").yields(stub("file", :puts => nil))
            @graph.expects(:to_dot).with("name" => @name.to_s.capitalize)
            Puppet[:graph] = true
            @graph.write_graph(@name)
        end

        after do
            Puppet.settings.clear
        end
    end

    describe Puppet::SimpleGraph do
        before do
            @graph = Puppet::SimpleGraph.new
        end

        it "should correctly clear vertices and edges when asked" do
            @graph.add_edge("a", "b")
            @graph.add_vertex "c"
            @graph.clear
            @graph.vertices.should be_empty
            @graph.edges.should be_empty
        end
    end

    describe "when matching edges" do
        before do
            @graph = Puppet::SimpleGraph.new
            @event = Puppet::Transaction::Event.new(:name => :yay, :resource => "a")
            @none = Puppet::Transaction::Event.new(:name => :NONE, :resource => "a")

            @edges = {}
            @edges["a/b"] = Puppet::Relationship.new("a", "b", {:event => :yay, :callback => :refresh})
            @edges["a/c"] = Puppet::Relationship.new("a", "c", {:event => :yay, :callback => :refresh})
            @graph.add_edge(@edges["a/b"])
        end

        it "should match edges whose source matches the source of the event" do
            @graph.matching_edges(@event).should == [@edges["a/b"]]
        end

        it "should match always match nothing when the event is :NONE" do
            @graph.matching_edges(@none).should be_empty
        end

        it "should match multiple edges" do
            @graph.add_edge(@edges["a/c"])
            edges = @graph.matching_edges(@event)
            edges.should be_include(@edges["a/b"])
            edges.should be_include(@edges["a/c"])
        end
    end

    describe "when determining dependencies" do
        before do
            @graph = Puppet::SimpleGraph.new

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

    describe "when splicing the graph" do
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
            @depgraph = Puppet::SimpleGraph.new
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
end
