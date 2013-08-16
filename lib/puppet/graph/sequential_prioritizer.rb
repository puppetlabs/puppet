# This implements a priority in which keys are given values that will keep them
# in the same priority in which they priorities are requested. Nested
# structures (those in which a key is contained within another key) are
# preserved in such a way that child keys are after the parent and before the
# key after the parent.
#
# @api private
class Puppet::Graph::SequentialPrioritizer < Puppet::Graph::Prioritizer
  def initialize
    super
    @container = {}
    @count = Puppet::Graph::Key.new
  end

  def generate_priority_for(key)
    if priority_of(key).nil?
      @count = @count.next
      record_priority_for(key, @count)
    else
      priority_of(key)
    end
  end

  def generate_priority_contained_in(container, key)
    @container[container] ||= priority_of(container).down
    priority = @container[container].next
    record_priority_for(key, priority)
    @container[container] = priority
    priority
  end
end
