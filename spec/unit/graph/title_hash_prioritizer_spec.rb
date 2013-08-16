require 'spec_helper'
require 'puppet/graph'

describe Puppet::Graph::TitleHashPrioritizer do
  it "produces different priorities for different resource references" do
    prioritizer = Puppet::Graph::TitleHashPrioritizer.new

    expect(prioritizer.generate_priority_for(resource(:notify, "one"))).to_not(
      eq(prioritizer.generate_priority_for(resource(:notify, "two"))))
  end

  it "always produces the same priority for the same resource ref" do
    a_prioritizer = Puppet::Graph::TitleHashPrioritizer.new
    another_prioritizer = Puppet::Graph::TitleHashPrioritizer.new

    expect(a_prioritizer.generate_priority_for(resource(:notify, "one"))).to(
      eq(another_prioritizer.generate_priority_for(resource(:notify, "one"))))
  end

  it "does not use the container when generating priorities" do
    prioritizer = Puppet::Graph::TitleHashPrioritizer.new

    expect(prioritizer.generate_priority_contained_in(nil, resource(:notify, "one"))).to(
      eq(prioritizer.generate_priority_for(resource(:notify, "one"))))
  end

  it "can retrieve a previously provided priority with the same resource" do
    prioritizer = Puppet::Graph::TitleHashPrioritizer.new
    resource = resource(:notify, "title")

    generated = prioritizer.generate_priority_for(resource)

    expect(prioritizer.priority_of(resource)).to eq(generated)
  end

  it "can not retrieve the priority of a resource with a different resource with the same title" do
    prioritizer = Puppet::Graph::TitleHashPrioritizer.new
    resource = resource(:notify, "title")
    different_resource = resource(:notify, "title")

    generated = prioritizer.generate_priority_for(resource)

    expect(prioritizer.priority_of(different_resource)).to be_nil
  end

  def resource(type, title)
    Puppet::Resource.new(type, title)
  end
end
