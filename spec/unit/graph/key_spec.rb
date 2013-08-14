require 'spec_helper'

require 'puppet/graph'

describe Puppet::Graph::Key do
  it "produces the next in the sequence" do
    key = Puppet::Graph::Key.new

    expect(key.next).to be > key
  end

  it "produces a key after itself but before next" do
    key = Puppet::Graph::Key.new
    expect(key.down).to be > key
    expect(key.down).to be < key.next
  end

  it "downward keys of the same group are in sequence" do
    key = Puppet::Graph::Key.new

    first = key.down
    middle = key.down.next
    last = key.down.next.next

    expect(first).to be < middle
    expect(middle).to be < last
    expect(last).to be < key.next
  end

  it "downward keys in sequential groups are in sequence" do
    key = Puppet::Graph::Key.new

    first = key.down
    middle = key.next
    last = key.next.down

    expect(first).to be < middle
    expect(middle).to be < last
    expect(last).to be < key.next.next
  end
end
