module Puppet::Pops
module Types
# keeps track of recursion of conceptual 'this' and 'that' instances using two separate maps and
# a state. All comparisons are made using the `object_id` of the instance rather than the instance
# itself.
# The state can have the following values:
#
# 0 - no recursion detected
# 1 - recursion detected in 'self'
# 2 - recursion detected in 'other'
# 3 - recursion detected in both 'self' and 'other'
#
# @api private
class RecursionGuard
  attr_reader :state

  def initialize
    @state = 0
  end

  # Checks if recursion was detected for the given argument in the 'this' context
  # @param instance [Object] the instance to check
  # @return [Integer] the resulting state
  def recursive_this?(instance)
    this_map[instance.object_id] == true
  end

  # Checks if recursion was detected for the given argument in the 'that' context
  # @param instance [Object] the instance to check
  # @return [Integer] the resulting state
  def recursive_that?(instance)
    that_map[instance.object_id] == true
  end

  # Add the given argument as 'this' and return the resulting state
  # @param instance [Object] the instance to add
  # @return [Integer] the resulting state
  def add_this(instance)
    if (@state & 1) == 0
      @state = @state | 1 if map_put(this_map, instance)
    end
    @state
  end

  # Add the given argument as 'that' and return the resulting state
  # @param instance [Object] the instance to add
  # @return [Integer] the resulting state
  def add_that(instance)
    if (@state & 2) == 0
      @state = @state | 2 if map_put(that_map, instance)
    end
    @state
  end

  private

  def map_put(map, o)
    id = o.object_id
    case map[id]
    when true
      true # Recursion already detected
    when false
      map[id] = true
      true # Recursion occured. This was the second time this entry was added
    else
      map[id] = false
      false # First time add. No recursion
    end
  end

  def this_map
    @this_map ||= {}
  end

  def that_map
    @that_map ||= {}
  end
end
end
end
