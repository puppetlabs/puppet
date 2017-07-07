#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/graph'

describe Puppet::Graph::SimpleGraph do
  it "should return the number of its vertices as its length" do
    @graph = Puppet::Graph::SimpleGraph.new
    @graph.add_vertex("one")
    @graph.add_vertex("two")
    expect(@graph.size).to eq(2)
  end

  it "should consider itself a directed graph" do
    expect(Puppet::Graph::SimpleGraph.new.directed?).to be_truthy
  end

  it "should provide a method for reversing the graph" do
    @graph = Puppet::Graph::SimpleGraph.new
    @graph.add_edge(:one, :two)
    expect(@graph.reversal.edge?(:two, :one)).to be_truthy
  end

  it "should be able to produce a dot graph" do
    @graph = Puppet::Graph::SimpleGraph.new
    class FauxVertex
      def ref
        "never mind"
      end
    end
    v1 = FauxVertex.new
    v2 = FauxVertex.new
    @graph.add_edge(v1, v2)

    expect { @graph.to_dot_graph }.to_not raise_error
  end

  describe "when managing vertices" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new
    end

    it "should provide a method to add a vertex" do
      @graph.add_vertex(:test)
      expect(@graph.vertex?(:test)).to be_truthy
    end

    it "should reset its reversed graph when vertices are added" do
      rev = @graph.reversal
      @graph.add_vertex(:test)
      expect(@graph.reversal).not_to equal(rev)
    end

    it "should ignore already-present vertices when asked to add a vertex" do
      @graph.add_vertex(:test)
      expect { @graph.add_vertex(:test) }.to_not raise_error
    end

    it "should return true when asked if a vertex is present" do
      @graph.add_vertex(:test)
      expect(@graph.vertex?(:test)).to be_truthy
    end

    it "should return false when asked if a non-vertex is present" do
      expect(@graph.vertex?(:test)).to be_falsey
    end

    it "should return all set vertices when asked" do
      @graph.add_vertex(:one)
      @graph.add_vertex(:two)
      expect(@graph.vertices.length).to eq(2)
      expect(@graph.vertices).to include(:one)
      expect(@graph.vertices).to include(:two)
    end

    it "should remove a given vertex when asked" do
      @graph.add_vertex(:one)
      @graph.remove_vertex!(:one)
      expect(@graph.vertex?(:one)).to be_falsey
    end

    it "should do nothing when a non-vertex is asked to be removed" do
      expect { @graph.remove_vertex!(:one) }.to_not raise_error
    end
  end

  describe "when managing edges" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new
    end

    it "should provide a method to test whether a given vertex pair is an edge" do
      expect(@graph).to respond_to(:edge?)
    end

    it "should reset its reversed graph when edges are added" do
      rev = @graph.reversal
      @graph.add_edge(:one, :two)
      expect(@graph.reversal).not_to equal(rev)
    end

    it "should provide a method to add an edge as an instance of the edge class" do
      edge = Puppet::Relationship.new(:one, :two)
      @graph.add_edge(edge)
      expect(@graph.edge?(:one, :two)).to be_truthy
    end

    it "should provide a method to add an edge by specifying the two vertices" do
      @graph.add_edge(:one, :two)
      expect(@graph.edge?(:one, :two)).to be_truthy
    end

    it "should provide a method to add an edge by specifying the two vertices and a label" do
      @graph.add_edge(:one, :two, :callback => :awesome)
      expect(@graph.edge?(:one, :two)).to be_truthy
    end

    describe "when retrieving edges between two nodes" do
      it "should handle the case of nodes not in the graph" do
        expect(@graph.edges_between(:one, :two)).to eq([])
      end

      it "should handle the case of nodes with no edges between them" do
        @graph.add_vertex(:one)
        @graph.add_vertex(:two)
        expect(@graph.edges_between(:one, :two)).to eq([])
      end

      it "should handle the case of nodes connected by a single edge" do
        edge = Puppet::Relationship.new(:one, :two)
        @graph.add_edge(edge)
        expect(@graph.edges_between(:one, :two).length).to eq(1)
        expect(@graph.edges_between(:one, :two)[0]).to equal(edge)
      end

      it "should handle the case of nodes connected by multiple edges" do
        edge1 = Puppet::Relationship.new(:one, :two, :callback => :foo)
        edge2 = Puppet::Relationship.new(:one, :two, :callback => :bar)
        @graph.add_edge(edge1)
        @graph.add_edge(edge2)
        expect(Set.new(@graph.edges_between(:one, :two))).to eq(Set.new([edge1, edge2]))
      end
    end

    it "should add the edge source as a vertex if it is not already" do
      edge = Puppet::Relationship.new(:one, :two)
      @graph.add_edge(edge)
      expect(@graph.vertex?(:one)).to be_truthy
    end

    it "should add the edge target as a vertex if it is not already" do
      edge = Puppet::Relationship.new(:one, :two)
      @graph.add_edge(edge)
      expect(@graph.vertex?(:two)).to be_truthy
    end

    it "should return all edges as edge instances when asked" do
      one = Puppet::Relationship.new(:one, :two)
      two = Puppet::Relationship.new(:two, :three)
      @graph.add_edge(one)
      @graph.add_edge(two)
      edges = @graph.edges
      expect(edges).to be_instance_of(Array)
      expect(edges.length).to eq(2)
      expect(edges).to include(one)
      expect(edges).to include(two)
    end

    it "should remove an edge when asked" do
      edge = Puppet::Relationship.new(:one, :two)
      @graph.add_edge(edge)
      @graph.remove_edge!(edge)
      expect(@graph.edge?(edge.source, edge.target)).to be_falsey
    end

    it "should remove all related edges when a vertex is removed" do
      one = Puppet::Relationship.new(:one, :two)
      two = Puppet::Relationship.new(:two, :three)
      @graph.add_edge(one)
      @graph.add_edge(two)
      @graph.remove_vertex!(:two)
      expect(@graph.edge?(:one, :two)).to be_falsey
      expect(@graph.edge?(:two, :three)).to be_falsey
      expect(@graph.edges.length).to eq(0)
    end
  end

  describe "when finding adjacent vertices" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new
      @one_two = Puppet::Relationship.new(:one, :two)
      @two_three = Puppet::Relationship.new(:two, :three)
      @one_three = Puppet::Relationship.new(:one, :three)
      @graph.add_edge(@one_two)
      @graph.add_edge(@one_three)
      @graph.add_edge(@two_three)
    end

    it "should return adjacent vertices" do
      adj = @graph.adjacent(:one)
      expect(adj).to be_include(:three)
      expect(adj).to be_include(:two)
    end

    it "should default to finding :out vertices" do
      expect(@graph.adjacent(:two)).to eq([:three])
    end

    it "should support selecting :in vertices" do
      expect(@graph.adjacent(:two, :direction => :in)).to eq([:one])
    end

    it "should default to returning the matching vertices as an array of vertices" do
      expect(@graph.adjacent(:two)).to eq([:three])
    end

    it "should support returning an array of matching edges" do
      expect(@graph.adjacent(:two, :type => :edges)).to eq([@two_three])
    end

    # Bug #2111
    it "should not consider a vertex adjacent just because it was asked about previously" do
      @graph = Puppet::Graph::SimpleGraph.new
      @graph.add_vertex("a")
      @graph.add_vertex("b")
      @graph.edge?("a", "b")
      expect(@graph.adjacent("a")).to eq([])
    end
  end

  describe "when clearing" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new
      one = Puppet::Relationship.new(:one, :two)
      two = Puppet::Relationship.new(:two, :three)
      @graph.add_edge(one)
      @graph.add_edge(two)

      @graph.clear
    end

    it "should remove all vertices" do
      expect(@graph.vertices).to be_empty
    end

    it "should remove all edges" do
      expect(@graph.edges).to be_empty
    end
  end

  describe "when reversing graphs" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new
    end

    it "should provide a method for reversing the graph" do
      @graph.add_edge(:one, :two)
      expect(@graph.reversal.edge?(:two, :one)).to be_truthy
    end

    it "should add all vertices to the reversed graph" do
      @graph.add_edge(:one, :two)
      expect(@graph.vertex?(:one)).to be_truthy
      expect(@graph.vertex?(:two)).to be_truthy
    end

    it "should retain labels on edges" do
      @graph.add_edge(:one, :two, :callback => :awesome)
      edge = @graph.reversal.edges_between(:two, :one)[0]
      expect(edge.label).to eq({:callback => :awesome})
    end
  end

  describe "when reporting cycles in the graph" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new
    end

    # This works with `add_edges` to auto-vivify the resource instances.
    let :vertex do
      Hash.new do |hash, key|
        hash[key] = Puppet::Type.type(:notify).new(:name => key.to_s)
      end
    end

    def add_edges(hash)
      hash.each do |a,b|
        @graph.add_edge(vertex[a], vertex[b])
      end
    end

    def simplify(cycles)
      cycles.map do |cycle|
        cycle.map do |resource|
          resource.name
        end
      end
    end

    def expect_cycle_to_include(cycle, *resource_names)
      resource_names.each_with_index do |resource, index|
        expect(cycle[index].ref).to eq("Notify[#{resource}]")
      end
    end

    it "should report two-vertex loops" do
      add_edges :a => :b, :b => :a
      Puppet.expects(:err).with(regexp_matches(/Found 1 dependency cycle:\n\(Notify\[a\] => Notify\[b\] => Notify\[a\]\)/))
      cycle = @graph.report_cycles_in_graph.first
      expect_cycle_to_include(cycle, :a, :b)
    end

    it "should report multi-vertex loops" do
      add_edges :a => :b, :b => :c, :c => :a
      Puppet.expects(:err).with(regexp_matches(/Found 1 dependency cycle:\n\(Notify\[a\] => Notify\[b\] => Notify\[c\] => Notify\[a\]\)/))
      cycle = @graph.report_cycles_in_graph.first
      expect_cycle_to_include(cycle, :a, :b, :c)
    end

    it "should report when a larger tree contains a small cycle" do
      add_edges :a => :b, :b => :a, :c => :a, :d => :c
      Puppet.expects(:err).with(regexp_matches(/Found 1 dependency cycle:\n\(Notify\[a\] => Notify\[b\] => Notify\[a\]\)/))
      cycle = @graph.report_cycles_in_graph.first
      expect_cycle_to_include(cycle, :a, :b)
    end

    it "should succeed on trees with no cycles" do
      add_edges :a => :b, :b => :e, :c => :a, :d => :c
      Puppet.expects(:err).never
      expect(@graph.report_cycles_in_graph).to be_nil
    end

    it "cycle discovery should be the minimum cycle for a simple graph" do
      add_edges "a" => "b"
      add_edges "b" => "a"
      add_edges "b" => "c"

      expect(simplify(@graph.find_cycles_in_graph)).to eq([["a", "b"]])
    end

    it "cycle discovery handles a self-loop cycle" do
      add_edges :a => :a

      expect(simplify(@graph.find_cycles_in_graph)).to eq([["a"]])
    end

    it "cycle discovery should handle two distinct cycles" do
      add_edges "a" => "a1", "a1" => "a"
      add_edges "b" => "b1", "b1" => "b"

      expect(simplify(@graph.find_cycles_in_graph)).to eq([["a1", "a"], ["b1", "b"]])
    end

    it "cycle discovery should handle two cycles in a connected graph" do
      add_edges "a" => "b", "b" => "c", "c" => "d"
      add_edges "a" => "a1", "a1" => "a"
      add_edges "c" => "c1", "c1" => "c2", "c2" => "c3", "c3" => "c"

      expect(simplify(@graph.find_cycles_in_graph)).to eq([%w{a1 a}, %w{c1 c2 c3 c}])
    end

    it "cycle discovery should handle a complicated cycle" do
      add_edges "a" => "b", "b" => "c"
      add_edges "a" => "c"
      add_edges "c" => "c1", "c1" => "a"
      add_edges "c" => "c2", "c2" => "b"

      expect(simplify(@graph.find_cycles_in_graph)).to eq([%w{a b c1 c2 c}])
    end

    it "cycle discovery should not fail with large data sets" do
      limit = 3000
      (1..(limit - 1)).each do |n| add_edges n.to_s => (n+1).to_s end

      expect(simplify(@graph.find_cycles_in_graph)).to eq([])
    end

    it "path finding should work with a simple cycle" do
      add_edges "a" => "b", "b" => "c", "c" => "a"

      cycles = @graph.find_cycles_in_graph
      paths = @graph.paths_in_cycle(cycles.first, 100)
      expect(simplify(paths)).to eq([%w{a b c a}])
    end

    it "path finding should work with two independent cycles" do
      add_edges "a" => "b1"
      add_edges "a" => "b2"
      add_edges "b1" => "a", "b2" => "a"

      cycles = @graph.find_cycles_in_graph
      expect(cycles.length).to eq(1)

      paths = @graph.paths_in_cycle(cycles.first, 100)
      expect(simplify(paths)).to eq([%w{a b1 a}, %w{a b2 a}])
    end

    it "path finding should prefer shorter paths in cycles" do
      add_edges "a" => "b", "b" => "c", "c" => "a"
      add_edges "b" => "a"

      cycles = @graph.find_cycles_in_graph
      expect(cycles.length).to eq(1)

      paths = @graph.paths_in_cycle(cycles.first, 100)
      expect(simplify(paths)).to eq([%w{a b a}, %w{a b c a}])
    end

    it "path finding should respect the max_path value" do
      (1..20).each do |n| add_edges "a" => "b#{n}", "b#{n}" => "a" end

      cycles = @graph.find_cycles_in_graph
      expect(cycles.length).to eq(1)

      (1..20).each do |n|
        paths = @graph.paths_in_cycle(cycles.first, n)
        expect(paths.length).to eq(n)
      end

      paths = @graph.paths_in_cycle(cycles.first, 21)
      expect(paths.length).to eq(20)
    end
  end

  describe "when writing dot files" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new
      @name = :test
      @file = File.join(Puppet[:graphdir], @name.to_s + ".dot")
    end

    it "should only write when graphing is enabled" do
      File.expects(:open).with(@file).never
      Puppet[:graph] = false
      @graph.write_graph(@name)
    end

    it "should write a dot file based on the passed name" do
      File.expects(:open).with(@file, "w:UTF-8").yields(stub("file", :puts => nil))
      @graph.expects(:to_dot).with("name" => @name.to_s.capitalize)
      Puppet[:graph] = true
      @graph.write_graph(@name)
    end
  end

  describe Puppet::Graph::SimpleGraph do
    before do
      @graph = Puppet::Graph::SimpleGraph.new
    end

    it "should correctly clear vertices and edges when asked" do
      @graph.add_edge("a", "b")
      @graph.add_vertex "c"
      @graph.clear
      expect(@graph.vertices).to be_empty
      expect(@graph.edges).to be_empty
    end
  end

  describe "when matching edges" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new

      # Resource is a String here although not for realz. Stub [] to always return nil
      # because indexing a String with a non-Integer throws an exception (and none of
      # these tests need anything meaningful from []).
      resource = "a"
      resource.stubs(:[])
      @event = Puppet::Transaction::Event.new(:name => :yay, :resource => resource)
      @none = Puppet::Transaction::Event.new(:name => :NONE, :resource => resource)

      @edges = {}
      @edges["a/b"] = Puppet::Relationship.new("a", "b", {:event => :yay, :callback => :refresh})
      @edges["a/c"] = Puppet::Relationship.new("a", "c", {:event => :yay, :callback => :refresh})
      @graph.add_edge(@edges["a/b"])
    end

    it "should match edges whose source matches the source of the event" do
      expect(@graph.matching_edges(@event)).to eq([@edges["a/b"]])
    end

    it "should match always match nothing when the event is :NONE" do
      expect(@graph.matching_edges(@none)).to be_empty
    end

    it "should match multiple edges" do
      @graph.add_edge(@edges["a/c"])
      edges = @graph.matching_edges(@event)
      expect(edges).to be_include(@edges["a/b"])
      expect(edges).to be_include(@edges["a/c"])
    end
  end

  describe "when determining dependencies" do
    before do
      @graph = Puppet::Graph::SimpleGraph.new

      @graph.add_edge("a", "b")
      @graph.add_edge("a", "c")
      @graph.add_edge("b", "d")
    end

    it "should find all dependents when they are on multiple levels" do
      expect(@graph.dependents("a").sort).to eq(%w{b c d}.sort)
    end

    it "should find single dependents" do
      expect(@graph.dependents("b").sort).to eq(%w{d}.sort)
    end

    it "should return an empty array when there are no dependents" do
      expect(@graph.dependents("c").sort).to eq([].sort)
    end

    it "should find all dependencies when they are on multiple levels" do
      expect(@graph.dependencies("d").sort).to eq(%w{a b})
    end

    it "should find single dependencies" do
      expect(@graph.dependencies("c").sort).to eq(%w{a})
    end

    it "should return an empty array when there are no dependencies" do
      expect(@graph.dependencies("a").sort).to eq([])
    end
  end

  it "should serialize to YAML using the old format by default" do
    expect(Puppet::Graph::SimpleGraph.use_new_yaml_format).to eq(false)
  end

  describe "(yaml tests)" do
    def empty_graph(graph)
    end

    def one_vertex_graph(graph)
      graph.add_vertex('a')
    end

    def graph_without_edges(graph)
      ['a', 'b', 'c'].each { |x| graph.add_vertex(x) }
    end

    def one_edge_graph(graph)
      graph.add_edge('a', 'b')
    end

    def many_edge_graph(graph)
      graph.add_edge('a', 'b')
      graph.add_edge('a', 'c')
      graph.add_edge('b', 'd')
      graph.add_edge('c', 'd')
    end

    def labeled_edge_graph(graph)
      graph.add_edge('a', 'b', :callback => :foo, :event => :bar)
    end

    def overlapping_edge_graph(graph)
      graph.add_edge('a', 'b', :callback => :foo, :event => :bar)
      graph.add_edge('a', 'b', :callback => :biz, :event => :baz)
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
      previous_use_new_yaml_format = Puppet::Graph::SimpleGraph.use_new_yaml_format
      Puppet::Graph::SimpleGraph.use_new_yaml_format = (which_format == :new)
      if block_given?
        yield
      else
        YAML.dump(graph)
      end
    ensure
      Puppet::Graph::SimpleGraph.use_new_yaml_format = previous_use_new_yaml_format
    end

    # Test serialization of graph to YAML.
    [:old, :new].each do |which_format|
      all_test_graphs.each do |graph_to_test|
        it "should be able to serialize #{graph_to_test} to YAML (#{which_format} format)" do
          graph = Puppet::Graph::SimpleGraph.new
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
          expect(serialized_object.keys.reject { |x| x == 'reversal' }.sort).to eq(['edges', 'vertices'])

          # Check edges by forming a set of tuples (source, target,
          # callback, event) based on the graph and the YAML and make sure
          # they match.
          edges = serialized_object['edges']
          expect(edges).to be_a(Array)
          expected_edge_tuples = graph.edges.collect { |edge| [edge.source, edge.target, edge.callback, edge.event] }
          actual_edge_tuples = edges.collect do |edge|
            %w{source target}.each { |x| expect(edge.keys).to include(x) }
            edge.keys.each { |x| expect(['source', 'target', 'callback', 'event']).to include(x) }
            %w{source target callback event}.collect { |x| edge[x] }
          end
          expect(Set.new(actual_edge_tuples)).to eq(Set.new(expected_edge_tuples.map { |tuple| tuple.map {|e| e.nil? ? nil : e.to_s }}))
          expect(actual_edge_tuples.length).to eq(expected_edge_tuples.length)

          # Check vertices one by one.
          vertices = serialized_object['vertices']
          if which_format == :old
            expect(vertices).to be_a(Hash)
            expect(Set.new(vertices.keys)).to eq(Set.new(graph.vertices))
            vertices.each do |key, value|
              expect(value.keys.sort).to eq(%w{adjacencies vertex})
              expect(value['vertex']).to eq(key)
              adjacencies = value['adjacencies']
              expect(adjacencies).to be_a(Hash)
              expect(Set.new(adjacencies.keys)).to eq(Set.new(['in', 'out']))
              [:in, :out].each do |direction|
                direction_hash = adjacencies[direction.to_s]
                expect(direction_hash).to be_a(Hash)
                expected_adjacent_vertices = Set.new(graph.adjacent(key, :direction => direction, :type => :vertices))
                expect(Set.new(direction_hash.keys)).to eq(expected_adjacent_vertices)
                direction_hash.each do |adj_key, adj_value|
                  # Since we already checked edges, just check consistency
                  # with edges.
                  desired_source = direction == :in ? adj_key : key
                  desired_target = direction == :in ? key : adj_key
                  expected_edges = edges.select do |edge|
                    edge['source'] == desired_source && edge['target'] == desired_target
                  end
                  expect(adj_value).to be_a(Array)
                  if adj_value != expected_edges
                    raise "For vertex #{key.inspect}, direction #{direction.inspect}: expected adjacencies #{expected_edges.inspect} but got #{adj_value.inspect}"
                  end
                end
              end
            end
          else
            expect(vertices).to be_a(Array)
            expect(Set.new(vertices)).to eq(Set.new(graph.vertices))
            expect(vertices.length).to eq(graph.vertices.length)
          end
        end
      end

      # Test deserialization of graph from YAML.  This presumes the
      # correctness of serialization to YAML, which has already been
      # tested.
      all_test_graphs.each do |graph_to_test|
        it "should be able to deserialize #{graph_to_test} from YAML (#{which_format} format)" do
          reference_graph = Puppet::Graph::SimpleGraph.new
          send(graph_to_test, reference_graph)
          yaml_form = graph_to_yaml(reference_graph, which_format)
          recovered_graph = YAML.load(yaml_form)

          # Test that the recovered vertices match the vertices in the
          # reference graph.
          expected_vertices = reference_graph.vertices.to_a
          recovered_vertices = recovered_graph.vertices.to_a
          expect(Set.new(recovered_vertices)).to eq(Set.new(expected_vertices))
          expect(recovered_vertices.length).to eq(expected_vertices.length)

          # Test that the recovered edges match the edges in the
          # reference graph.
          expected_edge_tuples = reference_graph.edges.collect do |edge|
            [edge.source, edge.target, edge.callback, edge.event]
          end
          recovered_edge_tuples = recovered_graph.edges.collect do |edge|
            [edge.source, edge.target, edge.callback, edge.event]
          end
          expect(Set.new(recovered_edge_tuples)).to eq(Set.new(expected_edge_tuples))
          expect(recovered_edge_tuples.length).to eq(expected_edge_tuples.length)

          # We ought to test that the recovered graph is self-consistent
          # too.  But we're not going to bother with that yet because
          # the internal representation of the graph is about to change.
        end
      end
    end

    it "should serialize properly when used as a base class" do
      class Puppet::TestDerivedClass < Puppet::Graph::SimpleGraph
        attr_accessor :foo

        def initialize_from_hash(hash)
          super(hash)
          @foo = hash['foo']
        end

        def to_data_hash
          super.merge('foo' => @foo)
        end
      end
      derived = Puppet::TestDerivedClass.new
      derived.add_edge('a', 'b')
      derived.foo = 1234
      yaml = YAML.dump(derived)
      recovered_derived = YAML.load(yaml)
      expect(recovered_derived.class).to equal(Puppet::TestDerivedClass)
      expect(recovered_derived.edges.length).to eq(1)
      expect(recovered_derived.edges[0].source).to eq('a')
      expect(recovered_derived.edges[0].target).to eq('b')
      expect(recovered_derived.vertices.length).to eq(2)
      expect(recovered_derived.foo).to eq(1234)
    end
  end
end
