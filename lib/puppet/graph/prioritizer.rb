# Base, template method, class for Prioritizers. This provides the basic
# tracking facilities used.
#
# @api private
class Puppet::Graph::Prioritizer
  def initialize
    @priority = {}
  end

  def forget(key)
    @priority.delete(key)
  end

  def record_priority_for(key, priority)
    @priority[key] = priority
  end

  def generate_priority_for(key)
    raise NotImplementedError
  end

  def generate_priority_contained_in(container, key)
    raise NotImplementedError
  end

  def priority_of(key)
    @priority[key]
  end
end
