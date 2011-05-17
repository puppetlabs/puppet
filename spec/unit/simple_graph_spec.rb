#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-11-1.
#  Copyright (c) 2006. All rights reserved.

require 'spec_helper'
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

    describe "when retrieving edges between two nodes" do
      it "should handle the case of nodes not in the graph" do
        @graph.edges_between(:one, :two).should == []
      end

      it "should handle the case of nodes with no edges between them" do
        @graph.add_vertex(:one)
        @graph.add_vertex(:two)
        @graph.edges_between(:one, :two).should == []
      end

      it "should handle the case of nodes connected by a single edge" do
        edge = Puppet::Relationship.new(:one, :two)
        @graph.add_edge(edge)
        @graph.edges_between(:one, :two).length.should == 1
        @graph.edges_between(:one, :two)[0].should equal(edge)
      end

      it "should handle the case of nodes connected by multiple edges" do
        edge1 = Puppet::Relationship.new(:one, :two, :callback => :foo)
        edge2 = Puppet::Relationship.new(:one, :two, :callback => :bar)
        @graph.add_edge(edge1)
        @graph.add_edge(edge2)
        Set.new(@graph.edges_between(:one, :two)).should == Set.new([edge1, edge2])
      end
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
      edge = @graph.reversal.edges_between(:two, :one)[0]
      edge.label.should == {:callback => :awesome}
    end
  end

  describe "when reporting cycles in the graph" do
    before do
      @graph = Puppet::SimpleGraph.new
    end

    def add_edges(hash)
      hash.each do |a,b|
        @graph.add_edge(a, b)
      end
    end

    it "should fail on two-vertex loops" do
      add_edges :a => :b, :b => :a
      proc { @graph.report_cycles_in_graph }.should raise_error(Puppet::Error)
    end

    it "should fail on multi-vertex loops" do
      add_edges :a => :b, :b => :c, :c => :a
      proc { @graph.report_cycles_in_graph }.should raise_error(Puppet::Error)
    end

    it "should fail when a larger tree contains a small cycle" do
      add_edges :a => :b, :b => :a, :c => :a, :d => :c
      proc { @graph.report_cycles_in_graph }.should raise_error(Puppet::Error)
    end

    it "should succeed on trees with no cycles" do
      add_edges :a => :b, :b => :e, :c => :a, :d => :c
      proc { @graph.report_cycles_in_graph }.should_not raise_error
    end

    it "should produce the correct relationship text" do
      add_edges :a => :b, :b => :a
      # cycle detection starts from a or b randomly
      # so we need to check for either ordering in the error message
      want = %r{Found 1 dependency cycle:\n\((a => b => a|b => a => b)\)\nTry}
      expect { @graph.report_cycles_in_graph }.to raise_error(Puppet::Error, want)
    end

    it "cycle discovery should be the minimum cycle for a simple graph" do
      add_edges "a" => "b"
      add_edges "b" => "a"
      add_edges "b" => "c"

      cycles = nil
      expect { cycles = @graph.find_cycles_in_graph.sort }.should_not raise_error
      cycles.should be == [["a", "b"]]
    end

    it "cycle discovery should handle two distinct cycles" do
      add_edges "a" => "a1", "a1" => "a"
      add_edges "b" => "b1", "b1" => "b"

      cycles = nil
      expect { cycles = @graph.find_cycles_in_graph.sort }.should_not raise_error
      cycles.should be == [["a", "a1"], ["b", "b1"]]
    end

    it "cycle discovery should handle two cycles in a connected graph" do
      add_edges "a" => "b", "b" => "c", "c" => "d"
      add_edges "a" => "a1", "a1" => "a"
      add_edges "c" => "c1", "c1" => "c2", "c2" => "c3", "c3" => "c"

      cycles = nil
      expect { cycles = @graph.find_cycles_in_graph.sort }.should_not raise_error
      cycles.should be == [%w{a a1}, %w{c c1 c2 c3}]
    end

    it "cycle discovery should handle a complicated cycle" do
      add_edges "a" => "b", "b" => "c"
      add_edges "a" => "c"
      add_edges "c" => "c1", "c1" => "a"
      add_edges "c" => "c2", "c2" => "b"

      cycles = nil
      expect { cycles = @graph.find_cycles_in_graph.sort }.should_not raise_error
      cycles.should be == [%w{a b c c1 c2}]
    end

    it "cycle discovery should not fail with large data sets" do
      limit = 3000
      (1..(limit - 1)).each do |n| add_edges n.to_s => (n+1).to_s end

      cycles = nil
      expect { cycles = @graph.find_cycles_in_graph.sort }.should_not raise_error
      cycles.should be == []
    end

    it "path finding should work with a simple cycle" do
      add_edges "a" => "b", "b" => "c", "c" => "a"

      cycles = @graph.find_cycles_in_graph.sort
      paths = @graph.paths_in_cycle(cycles.first, 100)
      paths.should be == [%w{a b c a}]
    end

    it "path finding should work with two independent cycles" do
      add_edges "a" => "b1"
      add_edges "a" => "b2"
      add_edges "b1" => "a", "b2" => "a"

      cycles = @graph.find_cycles_in_graph.sort
      cycles.length.should be == 1

      paths = @graph.paths_in_cycle(cycles.first, 100)
      paths.sort.should be == [%w{a b1 a}, %w{a b2 a}]
    end

    it "path finding should prefer shorter paths in cycles" do
      add_edges "a" => "b", "b" => "c", "c" => "a"
      add_edges "b" => "a"

      cycles = @graph.find_cycles_in_graph.sort
      cycles.length.should be == 1

      paths = @graph.paths_in_cycle(cycles.first, 100)
      paths.should be == [%w{a b a}, %w{a b c a}]
    end

    it "path finding should respect the max_path value" do
      (1..20).each do |n| add_edges "a" => "b#{n}", "b#{n}" => "a" end

      cycles = @graph.find_cycles_in_graph.sort
      cycles.length.should be == 1

      (1..20).each do |n|
        paths = @graph.paths_in_cycle(cycles.first, n)
        paths.length.should be == n
      end

      paths = @graph.paths_in_cycle(cycles.first, 21)
      paths.length.should be == 20
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

  describe "when matching edges", :'fails_on_ruby_1.9.2' => true do
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

  class Container < Puppet::Type::Component
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

    def ref
      "Container[#{self}]"
    end
  end

  require "puppet/resource/catalog"
  describe "when splicing the graph" do
    def container_graph
      @one = Container.new("one", %w{a b})
      @two = Container.new("two", ["c", "d"])
      @three = Container.new("three", ["i", "j"])
      @middle = Container.new("middle", ["e", "f", @two])
      @top = Container.new("top", ["g", "h", @middle, @one, @three])
      @empty = Container.new("empty", [])

      @whit  = Puppet::Type.type(:whit)
      @stage = Puppet::Type.type(:stage).new(:name => "foo")

      @contgraph = @top.to_graph(Puppet::Resource::Catalog.new)

      # We have to add the container to the main graph, else it won't
      # be spliced in the dependency graph.
      @contgraph.add_vertex(@empty)
    end

    def containers
      @contgraph.vertices.select { |x| !x.is_a? String }
    end

    def contents_of(x)
      @contgraph.direct_dependents_of(x)
    end

    def dependency_graph
      @depgraph = Puppet::SimpleGraph.new
      @contgraph.vertices.each do |v|
        @depgraph.add_vertex(v)
      end

      # We have to specify a relationship to our empty container, else it
      # never makes it into the dep graph in the first place.
      @explicit_dependencies = {@one => @two, "f" => "c", "h" => @middle, "c" => @empty}
      @explicit_dependencies.each do |source, target|
        @depgraph.add_edge(source, target, :callback => :refresh)
      end
    end

    def splice
      @contgraph.splice!(@depgraph)
    end

    def whit_called(name)
      x = @depgraph.vertices.find { |v| v.is_a?(@whit) && v.name =~ /#{Regexp.escape(name)}/ }
      x.should_not be_nil
      def x.to_s
        "Whit[#{name}]"
      end
      def x.inspect
        to_s
      end
      x
    end

    def admissible_sentinal_of(x)
      @depgraph.vertex?(x) ? x : whit_called("admissible_#{x.ref}")
    end

    def completed_sentinal_of(x)
      @depgraph.vertex?(x) ? x : whit_called("completed_#{x.ref}")
    end

    before do
      container_graph
      dependency_graph
      splice
    end

    # This is the real heart of splicing -- replacing all containers X in our
    # relationship graph with a pair of whits { admissible_X and completed_X }
    # such that that
    #
    #    0) completed_X depends on admissible_X
    #    1) contents of X each depend on admissible_X
    #    2) completed_X depends on each on the contents of X
    #    3) everything which depended on X depends on completed_X
    #    4) admissible_X depends on everything X depended on
    #    5) the containers and their edges must be removed
    #
    # Note that this requires attention to the possible case of containers
    # which contain or depend on other containers.
    #
    # Point by point:

    #    0) completed_X depends on admissible_X
    #
    it "every container's completed sentinal should depend on its admissible sentinal" do
      containers.each { |container|
        @depgraph.path_between(admissible_sentinal_of(container),completed_sentinal_of(container)).should be
      }
    end

    #    1) contents of X each depend on admissible_X
    #
    it "all contained objects should depend on their container's admissible sentinal" do
      containers.each { |container|
        contents_of(container).each { |leaf|
          @depgraph.should be_edge(admissible_sentinal_of(container),admissible_sentinal_of(leaf))
        }
      }
    end

    #    2) completed_X depends on each on the contents of X
    #
    it "completed sentinals should depend on their container's contents" do
      containers.each { |container|
        contents_of(container).each { |leaf|
          @depgraph.should be_edge(completed_sentinal_of(leaf),completed_sentinal_of(container))
        }
      }
    end

    #
    #    3) everything which depended on X depends on completed_X

    #
    #    4) admissible_X depends on everything X depended on

    #    5) the containers and their edges must be removed
    #
    it "should remove all Container objects from the dependency graph" do
      @depgraph.vertices.find_all { |v| v.is_a?(Container) }.should be_empty
    end

    it "should remove all Stage resources from the dependency graph" do
      @depgraph.vertices.find_all { |v| v.is_a?(Puppet::Type.type(:stage)) }.should be_empty
    end

    it "should no longer contain anything but the non-container objects" do
      @depgraph.vertices.find_all { |v| ! v.is_a?(String) and ! v.is_a?(@whit)}.should be_empty
    end

    it "should retain labels on non-containment edges" do
      @explicit_dependencies.each { |f,t|
        @depgraph.edges_between(completed_sentinal_of(f),admissible_sentinal_of(t))[0].label.should == {:callback => :refresh}
      }
    end

    it "should not add labels to edges that have none" do
      @depgraph.add_edge(@two, @three)
      splice
      @depgraph.path_between("c", "i").any? {|segment| segment.all? {|e| e.label == {} }}.should be
    end

    it "should copy labels over edges that have none" do
      @depgraph.add_edge("c", @three, {:callback => :refresh})
      splice
      # And make sure the label got copied.
      @depgraph.path_between("c", "i").flatten.select {|e| e.label == {:callback => :refresh} }.should_not be_empty
    end

    it "should not replace a label with a nil label" do
      # Lastly, add some new label-less edges and make sure the label stays.
      @depgraph.add_edge(@middle, @three)
      @depgraph.add_edge("c", @three, {:callback => :refresh})
      splice
      @depgraph.path_between("c","i").flatten.select {|e| e.label == {:callback => :refresh} }.should_not be_empty
    end

    it "should copy labels to all created edges" do
      @depgraph.add_edge(@middle, @three)
      @depgraph.add_edge("c", @three, {:callback => :refresh})
      splice
      @three.each do |child|
        edge = Puppet::Relationship.new("c", child)
        (path = @depgraph.path_between(edge.source, edge.target)).should be
        path.should_not be_empty
        path.flatten.select {|e| e.label == {:callback => :refresh} }.should_not be_empty
      end
    end
  end

  it "should serialize to YAML using the old format by default" do
    Puppet::SimpleGraph.use_new_yaml_format.should == false
  end

  describe "(yaml tests)" do
    def empty_graph(graph)
    end

    def one_vertex_graph(graph)
      graph.add_vertex(:a)
    end

    def graph_without_edges(graph)
      [:a, :b, :c].each { |x| graph.add_vertex(x) }
    end

    def one_edge_graph(graph)
      graph.add_edge(:a, :b)
    end

    def many_edge_graph(graph)
      graph.add_edge(:a, :b)
      graph.add_edge(:a, :c)
      graph.add_edge(:b, :d)
      graph.add_edge(:c, :d)
    end

    def labeled_edge_graph(graph)
      graph.add_edge(:a, :b, :callback => :foo, :event => :bar)
    end

    def overlapping_edge_graph(graph)
      graph.add_edge(:a, :b, :callback => :foo, :event => :bar)
      graph.add_edge(:a, :b, :callback => :biz, :event => :baz)
    end

    def self.all_test_graphs
      [:empty_graph, :one_vertex_graph, :graph_without_edges, :one_edge_graph, :many_edge_graph, :labeled_edge_graph,
       :overlapping_edge_graph]
    end

    def object_ids(enumerable)
      # Return a sorted list of the object id's of the elements of an
      # enumerable.
      enumerable.collect { |x| x.object_id }.sort
    end

    def graph_to_yaml(graph, which_format)
      previous_use_new_yaml_format = Puppet::SimpleGraph.use_new_yaml_format
      Puppet::SimpleGraph.use_new_yaml_format = (which_format == :new)
      ZAML.dump(graph)
    ensure
      Puppet::SimpleGraph.use_new_yaml_format = previous_use_new_yaml_format
    end

    # Test serialization of graph to YAML.
    [:old, :new].each do |which_format|
      all_test_graphs.each do |graph_to_test|
        it "should be able to serialize #{graph_to_test} to YAML (#{which_format} format)" do
          graph = Puppet::SimpleGraph.new
          send(graph_to_test, graph)
          yaml_form = graph_to_yaml(graph, which_format)

          # Hack the YAML so that objects in the Puppet namespace get
          # changed to YAML::DomainType objects.  This lets us inspect
          # the serialized objects easily without invoking any
          # yaml_initialize hooks.
          yaml_form.gsub!('!ruby/object:Puppet::', '!hack/object:Puppet::')
          serialized_object = YAML.load(yaml_form)

          # Check that the object contains instance variables @edges and
          # @vertices only.  @reversal is also permitted, but we don't
          # check it, because it is going to be phased out.
          serialized_object.type_id.should == 'object:Puppet::SimpleGraph'
          serialized_object.value.keys.reject { |x| x == 'reversal' }.sort.should == ['edges', 'vertices']

          # Check edges by forming a set of tuples (source, target,
          # callback, event) based on the graph and the YAML and make sure
          # they match.
          edges = serialized_object.value['edges']
          edges.should be_a(Array)
          expected_edge_tuples = graph.edges.collect { |edge| [edge.source, edge.target, edge.callback, edge.event] }
          actual_edge_tuples = edges.collect do |edge|
            edge.type_id.should == 'object:Puppet::Relationship'
            %w{source target}.each { |x| edge.value.keys.should include(x) }
            edge.value.keys.each { |x| ['source', 'target', 'callback', 'event'].should include(x) }
            %w{source target callback event}.collect { |x| edge.value[x] }
          end
          Set.new(actual_edge_tuples).should == Set.new(expected_edge_tuples)
          actual_edge_tuples.length.should == expected_edge_tuples.length

          # Check vertices one by one.
          vertices = serialized_object.value['vertices']
          if which_format == :old
            vertices.should be_a(Hash)
            Set.new(vertices.keys).should == Set.new(graph.vertices)
            vertices.each do |key, value|
              value.type_id.should == 'object:Puppet::SimpleGraph::VertexWrapper'
              value.value.keys.sort.should == %w{adjacencies vertex}
              value.value['vertex'].should equal(key)
              adjacencies = value.value['adjacencies']
              adjacencies.should be_a(Hash)
              Set.new(adjacencies.keys).should == Set.new([:in, :out])
              [:in, :out].each do |direction|
                adjacencies[direction].should be_a(Hash)
                expected_adjacent_vertices = Set.new(graph.adjacent(key, :direction => direction, :type => :vertices))
                Set.new(adjacencies[direction].keys).should == expected_adjacent_vertices
                adjacencies[direction].each do |adj_key, adj_value|
                  # Since we already checked edges, just check consistency
                  # with edges.
                  desired_source = direction == :in ? adj_key : key
                  desired_target = direction == :in ? key : adj_key
                  expected_edges = edges.select do |edge|
                    edge.value['source'] == desired_source && edge.value['target'] == desired_target
                  end
                  adj_value.should be_a(Set)
                  if object_ids(adj_value) != object_ids(expected_edges)
                    raise "For vertex #{key.inspect}, direction #{direction.inspect}: expected adjacencies #{expected_edges.inspect} but got #{adj_value.inspect}"
                  end
                end
              end
            end
          else
            vertices.should be_a(Array)
            Set.new(vertices).should == Set.new(graph.vertices)
            vertices.length.should == graph.vertices.length
          end
        end
      end

      # Test deserialization of graph from YAML.  This presumes the
      # correctness of serialization to YAML, which has already been
      # tested.
      all_test_graphs.each do |graph_to_test|
        it "should be able to deserialize #{graph_to_test} from YAML (#{which_format} format)" do
          reference_graph = Puppet::SimpleGraph.new
          send(graph_to_test, reference_graph)
          yaml_form = graph_to_yaml(reference_graph, which_format)
          recovered_graph = YAML.load(yaml_form)

          # Test that the recovered vertices match the vertices in the
          # reference graph.
          expected_vertices = reference_graph.vertices.to_a
          recovered_vertices = recovered_graph.vertices.to_a
          Set.new(recovered_vertices).should == Set.new(expected_vertices)
          recovered_vertices.length.should == expected_vertices.length

          # Test that the recovered edges match the edges in the
          # reference graph.
          expected_edge_tuples = reference_graph.edges.collect do |edge|
            [edge.source, edge.target, edge.callback, edge.event]
          end
          recovered_edge_tuples = recovered_graph.edges.collect do |edge|
            [edge.source, edge.target, edge.callback, edge.event]
          end
          Set.new(recovered_edge_tuples).should == Set.new(expected_edge_tuples)
          recovered_edge_tuples.length.should == expected_edge_tuples.length

          # We ought to test that the recovered graph is self-consistent
          # too.  But we're not going to bother with that yet because
          # the internal representation of the graph is about to change.
        end
      end

      it "should be able to serialize a graph where the vertices contain backreferences to the graph (#{which_format} format)" do
        reference_graph = Puppet::SimpleGraph.new
        vertex = Object.new
        vertex.instance_eval { @graph = reference_graph }
        reference_graph.add_edge(vertex, :other_vertex)
        yaml_form = graph_to_yaml(reference_graph, which_format)
        recovered_graph = YAML.load(yaml_form)

        recovered_graph.vertices.length.should == 2
        recovered_vertex = recovered_graph.vertices.reject { |x| x.is_a?(Symbol) }[0]
        recovered_vertex.instance_eval { @graph }.should equal(recovered_graph)
        recovered_graph.edges.length.should == 1
        recovered_edge = recovered_graph.edges[0]
        recovered_edge.source.should equal(recovered_vertex)
        recovered_edge.target.should == :other_vertex
      end
    end

    it "should serialize properly when used as a base class" do
      class Puppet::TestDerivedClass < Puppet::SimpleGraph
        attr_accessor :foo
      end
      derived = Puppet::TestDerivedClass.new
      derived.add_edge(:a, :b)
      derived.foo = 1234
      recovered_derived = YAML.load(YAML.dump(derived))
      recovered_derived.class.should equal(Puppet::TestDerivedClass)
      recovered_derived.edges.length.should == 1
      recovered_derived.edges[0].source.should == :a
      recovered_derived.edges[0].target.should == :b
      recovered_derived.vertices.length.should == 2
      recovered_derived.foo.should == 1234
    end
  end
end
