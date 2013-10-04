# Assign a random priority to items.
#
# @api private
class Puppet::Graph::RandomPrioritizer < Puppet::Graph::Prioritizer
  def generate_priority_for(key)
    if priority_of(key).nil?
      record_priority_for(key, SecureRandom.uuid)
    else
      priority_of(key)
    end
  end

  def generate_priority_contained_in(container, key)
    generate_priority_for(key)
  end
end
