#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/relationship_graph'

describe Puppet::RelationshipGraph do
  def stub_vertex(name)
    stub "vertex #{name}", :ref => name
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
end
