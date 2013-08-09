#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/relationship_graph'
require 'puppet_spec/compiler'
require 'matchers/include_in_order'

describe Puppet::RelationshipGraph do
  include PuppetSpec::Compiler

  def stub_vertex(name)
    stub "vertex #{name}", :ref => name
  end

  it "allows adding a new vertex with a specific priority" do
    graph = Puppet::RelationshipGraph.new
    vertex = stub_vertex('something')

    graph.add_vertex(vertex, 2)

    expect(graph.resource_priority(vertex)).to eq(2)
  end

  it "returns resource priority based on the order added" do
    graph = Puppet::RelationshipGraph.new

    # strings chosen so the old hex digest method would put these in the
    # wrong order
    first = stub_vertex('aa')
    second = stub_vertex('b')

    graph.add_vertex(first)
    graph.add_vertex(second)

    expect(graph.resource_priority(first)).to be < graph.resource_priority(second)
  end

  it "retains the first priority when a resource is added more than once" do
    graph = Puppet::RelationshipGraph.new

    first = stub_vertex(1)
    second = stub_vertex(2)

    graph.add_vertex(first)
    graph.add_vertex(second)
    graph.add_vertex(first)

    expect(graph.resource_priority(first)).to be < graph.resource_priority(second)
  end

  it "forgets the priority of a removed resource" do
    graph = Puppet::RelationshipGraph.new

    vertex = stub_vertex(1)

    graph.add_vertex(vertex)
    graph.remove_vertex!(vertex)

    expect(graph.resource_priority(vertex)).to be_nil
  end

  it "does not give two resources the same priority" do
    graph = Puppet::RelationshipGraph.new

    first = stub_vertex(1)
    second = stub_vertex(2)
    third = stub_vertex(3)

    graph.add_vertex(first)
    graph.add_vertex(second)
    graph.remove_vertex!(first)
    graph.add_vertex(third)

    expect(graph.resource_priority(second)).to be < graph.resource_priority(third)
  end

  context "order of traversal" do
    it "traverses independent resources in the order they are added" do
      relationships = compile_to_relationship_graph(<<-MANIFEST)
        notify { "first": }
        notify { "second": }
        notify { "third": }
        notify { "fourth": }
        notify { "fifth": }
      MANIFEST

      expect(order_resources_traversed_in(relationships)).to(
        include_in_order("Notify[first]",
                         "Notify[second]",
                         "Notify[third]",
                         "Notify[fourth]",
                         "Notify[fifth]"))
    end

    it "traverses resources generated during catalog creation in the order inserted" do
      relationships = compile_to_relationship_graph(<<-MANIFEST)
        create_resources(notify, { "first" => {} })
        create_resources(notify, { "second" => {} })
        notify{ "third": }
        create_resources(notify, { "fourth" => {} })
        create_resources(notify, { "fifth" => {} })
      MANIFEST

      expect(order_resources_traversed_in(relationships)).to(
        include_in_order("Notify[first]",
                         "Notify[second]",
                         "Notify[third]",
                         "Notify[fourth]",
                         "Notify[fifth]"))
    end

    it "traverses all independent resources before traversing dependent ones" do
      relationships = compile_to_relationship_graph(<<-MANIFEST)
        notify { "first": require => Notify[third] }
        notify { "second": }
        notify { "third": }
      MANIFEST

      expect(order_resources_traversed_in(relationships)).to(
        include_in_order("Notify[second]", "Notify[third]", "Notify[first]"))
    end

    it "traverses resources in classes in the order they are added" do
      relationships = compile_to_relationship_graph(<<-MANIFEST)
        class c1 {
            notify { "a": }
            notify { "b": }
        }
        class c2 {
            notify { "c": require => Notify[b] }
        }
        class c3 {
            notify { "d": }
        }
        include c2
        include c1
        include c3
      MANIFEST

      expect(order_resources_traversed_in(relationships)).to(
        include_in_order("Notify[a]", "Notify[b]", "Notify[c]", "Notify[d]"))
    end

    it "traverses resources in defines in the order they are added" do
      relationships = compile_to_relationship_graph(<<-MANIFEST)
        define d1() {
          notify { "a": }
          notify { "b": }
        }
        define d2() {
          notify { "c": require => Notify[b]}
        }
        define d3() {
            notify { "d": }
        }
        d2 { "c": }
        d1 { "d": }
        d3 { "e": }
      MANIFEST

      expect(order_resources_traversed_in(relationships)).to(
        include_in_order("Notify[a]", "Notify[b]", "Notify[c]", "Notify[d]"))
    end

    def order_resources_traversed_in(relationships)
      order_seen = []
      relationships.traverse { |resource| order_seen << resource.ref }
      order_seen
    end
  end

  describe "when reconstruction containment relationships" do
    def vertex_called(graph, name)
      graph.vertices.find { |v| v.ref =~ /#{Regexp.escape(name)}/ }
    end

    def admissible_sentinel_of(graph, ref)
      vertex_called(graph, "Admissible_#{ref}")
    end

    def completed_sentinel_of(graph, ref)
      vertex_called(graph, "Completed_#{ref}")
    end

    it "an empty container's completed sentinel should depend on its admissible sentinel" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a { }

        include a
      MANIFEST

      relationship_graph.
        should be_edge(
          admissible_sentinel_of(relationship_graph, "class[A]"),
          completed_sentinel_of(relationship_graph, "class[A]"))
    end

    it "a container with children does not connect the completed sentinel to its admissible sentinel" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a { notify { "a": } }

        include a
      MANIFEST

      relationship_graph.
        should_not be_edge(
          admissible_sentinel_of(relationship_graph, "class[A]"),
          completed_sentinel_of(relationship_graph, "class[A]"))
    end

    it "all contained objects should depend on their container's admissible sentinel" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
          notify { "class a": }
        }

        include a
      MANIFEST

      relationship_graph.
        should be_edge(
          admissible_sentinel_of(relationship_graph, "class[A]"),
          vertex_called(relationship_graph, "Notify[class a]"))
    end

    it "completed sentinels should depend on their container's contents" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
          notify { "class a": }
        }

        include a
      MANIFEST

      relationship_graph.
        should be_edge(
          vertex_called(relationship_graph, "Notify[class a]"),
          completed_sentinel_of(relationship_graph, "class[A]"))
    end

    it "should remove all Component objects from the dependency graph" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
          notify { "class a": }
        }
        define b() {
          notify { "define b": }
        }

        include a
        b { "testing": }
      MANIFEST

      relationship_graph.vertices.find_all { |v| v.is_a?(Puppet::Type.type(:component)) }.should be_empty
    end

    it "should remove all Stage resources from the dependency graph" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        notify { "class a": }
      MANIFEST

      relationship_graph.vertices.find_all { |v| v.is_a?(Puppet::Type.type(:stage)) }.should be_empty
    end

    it "should retain labels on non-containment edges" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
          notify { "class a": }
        }
        define b() {
          notify { "define b": }
        }

        include a
        Class[a] ~> b { "testing": }
      MANIFEST

      relationship_graph.edges_between(
        completed_sentinel_of(relationship_graph, "class[A]"),
        admissible_sentinel_of(relationship_graph, "b[testing]"))[0].label.
        should == {:callback => :refresh, :event => :ALL_EVENTS}
    end

    it "should not add labels to edges that have none" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
          notify { "class a": }
        }
        define b() {
          notify { "define b": }
        }

        include a
        Class[a] -> b { "testing": }
      MANIFEST

      relationship_graph.edges_between(
        completed_sentinel_of(relationship_graph, "class[A]"),
        admissible_sentinel_of(relationship_graph, "b[testing]"))[0].label.
        should be_empty
    end

    it "should copy notification labels to all created edges" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
          notify { "class a": }
        }
        define b() {
          notify { "define b": }
        }

        include a
        Class[a] ~> b { "testing": }
      MANIFEST

      relationship_graph.edges_between(
        admissible_sentinel_of(relationship_graph, "b[testing]"),
        vertex_called(relationship_graph, "Notify[define b]"))[0].label.
        should == {:callback => :refresh, :event => :ALL_EVENTS}
    end
  end
end
