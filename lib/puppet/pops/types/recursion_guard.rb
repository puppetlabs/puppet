module Puppet::Pops
module Types
# Keeps track of self recursion of conceptual 'this' and 'that' instances using two separate maps and
# a state. The class is used when tracking self recursion in two objects ('this' and 'that') simultaneously.
# A typical example of when this is needed is when testing if 'that' Puppet Type is assignable to 'this'
# Puppet Type since both types may contain self references.
#
# All comparisons are made using the `object_id` of the instance rather than the instance itself.
#
# @api private
class RecursionGuard
  attr_reader :state

  NO_SELF_RECURSION = 0
  SELF_RECURSION_IN_THIS = 1
  SELF_RECURSION_IN_THAT = 2
  SELF_RECURSION_IN_BOTH = 3

  def initialize
    @state = NO_SELF_RECURSION
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
    if (@state & SELF_RECURSION_IN_THIS) == 0
      @state = @state | SELF_RECURSION_IN_THIS if map_put(this_map, instance)
    end
    @state
  end

  # Add the given argument as 'that' and return the resulting state
  # @param instance [Object] the instance to add
  # @return [Integer] the resulting state
  def add_that(instance)
    if (@state & SELF_RECURSION_IN_THAT) == 0
      @state = @state | SELF_RECURSION_IN_THAT if map_put(that_map, instance)
    end
    @state
  end

  # @return the number of objects added to the `this` map
  def this_count
    this_map.size
  end

  # @return the number of objects added to the `that` map
  def that_count
    that_map.size
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
