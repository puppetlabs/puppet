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
end
