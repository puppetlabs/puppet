#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/graph'

require 'puppet_spec/compiler'
require 'matchers/include_in_order'
require 'matchers/relationship_graph_matchers'

describe Puppet::Graph::RelationshipGraph do
  include PuppetSpec::Files
  include PuppetSpec::Compiler
  include RelationshipGraphMatchers

  let(:graph) { Puppet::Graph::RelationshipGraph.new(Puppet::Graph::SequentialPrioritizer.new) }

  it "allows adding a new vertex with a specific priority" do
    vertex = stub_vertex('something')

    graph.add_vertex(vertex, 2)

    expect(graph.resource_priority(vertex)).to eq(2)
  end

  it "returns resource priority based on the order added" do
    # strings chosen so the old hex digest method would put these in the
    # wrong order
    first = stub_vertex('aa')
    second = stub_vertex('b')

    graph.add_vertex(first)
    graph.add_vertex(second)

    expect(graph.resource_priority(first)).to be < graph.resource_priority(second)
  end

  it "retains the first priority when a resource is added more than once" do
    first = stub_vertex(1)
    second = stub_vertex(2)

    graph.add_vertex(first)
    graph.add_vertex(second)
    graph.add_vertex(first)

    expect(graph.resource_priority(first)).to be < graph.resource_priority(second)
  end

  it "forgets the priority of a removed resource" do
    vertex = stub_vertex(1)

    graph.add_vertex(vertex)
    graph.remove_vertex!(vertex)

    expect(graph.resource_priority(vertex)).to be_nil
  end

  it "does not give two resources the same priority" do
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

    it "traverses all independent resources before traversing dependent ones (with a backwards require)" do
      relationships = compile_to_relationship_graph(<<-MANIFEST)
        notify { "first": }
        notify { "second": }
        notify { "third": require => Notify[second] }
        notify { "fourth": }
      MANIFEST

      expect(order_resources_traversed_in(relationships)).to(
        include_in_order("Notify[first]", "Notify[second]", "Notify[third]", "Notify[fourth]"))
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
  end

  describe "when interrupting traversal" do
    def collect_canceled_resources(relationships, trigger_on)
      continue = true
      continue_while = lambda { continue }

      canceled_resources = []
      canceled_resource_handler = lambda { |resource| canceled_resources << resource.ref }

      relationships.traverse(:while => continue_while,
                             :canceled_resource_handler => canceled_resource_handler) do |resource|
        if resource.ref == trigger_on
          continue = false
        end
      end

      canceled_resources
    end

    it "enumerates the remaining resources" do
      relationships = compile_to_relationship_graph(<<-MANIFEST)
      notify { "a": }
      notify { "b": }
      notify { "c": }
    MANIFEST
      resources = collect_canceled_resources(relationships, 'Notify[b]')

      expect(resources).to include('Notify[c]')
    end

    it "enumerates the remaining blocked resources" do
      relationships = compile_to_relationship_graph(<<-MANIFEST)
      notify { "a": }
      notify { "b": }
      notify { "c": }
      notify { "d": require => Notify["c"] }
    MANIFEST
      resources = collect_canceled_resources(relationships, 'Notify[b]')

      expect(resources).to include('Notify[d]')
    end
  end

  describe "when constructing dependencies" do
    let(:child) { make_absolute('/a/b') }
    let(:parent) { make_absolute('/a') }

    it "does not create an automatic relationship that would interfere with a manual relationship" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        file { "#{child}": }

        file { "#{parent}": require => File["#{child}"] }
      MANIFEST

      expect(relationship_graph).to enforce_order_with_edge("File[#{child}]", "File[#{parent}]")
    end

    it "creates automatic relationships defined by the type" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        file { "#{child}": }

        file { "#{parent}": }
      MANIFEST

      expect(relationship_graph).to enforce_order_with_edge("File[#{parent}]", "File[#{child}]")
    end
  end

  describe "when reconstructing containment relationships" do
    def admissible_sentinel_of(ref)
      "Admissible_#{ref}"
    end

    def completed_sentinel_of(ref)
      "Completed_#{ref}"
    end

    it "an empty container's completed sentinel should depend on its admissible sentinel" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a { }

        include a
      MANIFEST

      expect(relationship_graph).to enforce_order_with_edge(
        admissible_sentinel_of("class[A]"),
        completed_sentinel_of("class[A]"))
    end

    it "a container with children does not directly connect the completed sentinel to its admissible sentinel" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a { notify { "a": } }

        include a
      MANIFEST

      expect(relationship_graph).not_to enforce_order_with_edge(
        admissible_sentinel_of("class[A]"),
        completed_sentinel_of("class[A]"))
    end

    it "all contained objects should depend on their container's admissible sentinel" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
          notify { "class a": }
        }

        include a
      MANIFEST

      expect(relationship_graph).to enforce_order_with_edge(
        admissible_sentinel_of("class[A]"),
        "Notify[class a]")
    end

    it "completed sentinels should depend on their container's contents" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
          notify { "class a": }
        }

        include a
      MANIFEST

      expect(relationship_graph).to enforce_order_with_edge(
          "Notify[class a]",
          completed_sentinel_of("class[A]"))
    end

    it "admissible and completed sentinels should inherit the same tags" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        class a {
	  tag "test_tag"
        }

        include a
      MANIFEST

      expect(vertex_called(relationship_graph, admissible_sentinel_of("class[A]")).tagged?("test_tag")).
      to eq(true)
      expect(vertex_called(relationship_graph, completed_sentinel_of("class[A]")).tagged?("test_tag")).
      to eq(true)
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

      expect(relationship_graph.vertices.find_all { |v| v.is_a?(Puppet::Type.type(:component)) }).to be_empty
    end

    it "should remove all Stage resources from the dependency graph" do
      relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
        notify { "class a": }
      MANIFEST

      expect(relationship_graph.vertices.find_all { |v| v.is_a?(Puppet::Type.type(:stage)) }).to be_empty
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

      expect(relationship_graph.edges_between(
        vertex_called(relationship_graph, completed_sentinel_of("class[A]")),
        vertex_called(relationship_graph, admissible_sentinel_of("b[testing]")))[0].label).
        to eq({:callback => :refresh, :event => :ALL_EVENTS})
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

      expect(relationship_graph.edges_between(
        vertex_called(relationship_graph, completed_sentinel_of("class[A]")),
        vertex_called(relationship_graph, admissible_sentinel_of("b[testing]")))[0].label).
        to be_empty
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

      expect(relationship_graph.edges_between(
        vertex_called(relationship_graph, admissible_sentinel_of("b[testing]")),
        vertex_called(relationship_graph, "Notify[define b]"))[0].label).
        to eq({:callback => :refresh, :event => :ALL_EVENTS})
    end
  end

  def vertex_called(graph, name)
    graph.vertices.find { |v| v.ref =~ /#{Regexp.escape(name)}/ }
  end

  def stub_vertex(name)
    stub "vertex #{name}", :ref => name
  end
end
