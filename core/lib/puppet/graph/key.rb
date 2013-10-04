# Sequential, nestable keys for tracking order of insertion in "the graph"
# @api private
class Puppet::Graph::Key
  include Comparable

  attr_reader :value
  protected :value

  def initialize(value = [0])
    @value = value
  end

  def next
    next_values = @value.clone
    next_values[-1] += 1
    Puppet::Graph::Key.new(next_values)
  end

  def down
    Puppet::Graph::Key.new(@value + [0])
  end

  def <=>(other)
    @value <=> other.value
  end
end
