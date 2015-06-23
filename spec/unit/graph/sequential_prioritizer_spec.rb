require 'spec_helper'
require 'puppet/graph'

describe Puppet::Graph::SequentialPrioritizer do
  let(:priorities) { Puppet::Graph::SequentialPrioritizer.new }

  it "generates priorities that maintain the sequence" do
    first = priorities.generate_priority_for("one")
    second = priorities.generate_priority_for("two")
    third = priorities.generate_priority_for("three")

    expect(first).to be < second
    expect(second).to be < third
  end

  it "prioritizes contained keys after the container" do
    parent = priorities.generate_priority_for("one")
    child = priorities.generate_priority_contained_in("one", "child 1")
    sibling = priorities.generate_priority_contained_in("one", "child 2")
    uncle = priorities.generate_priority_for("two")

    expect(parent).to be < child
    expect(child).to be < sibling
    expect(sibling).to be < uncle
  end

  it "fails to prioritize a key contained in an unknown container" do
    expect do
      priorities.generate_priority_contained_in("unknown", "child 1")
    end.to raise_error(NoMethodError, /`down' for nil/)
  end
end
