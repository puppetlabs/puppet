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
    instance_variable_defined?(:@recursive_this_map) && @recursive_this_map.has_key?(instance.object_id)
  end

  # Checks if recursion was detected for the given argument in the 'that' context
  # @param instance [Object] the instance to check
  # @return [Integer] the resulting state
  def recursive_that?(instance)
    instance_variable_defined?(:@recursive_that_map) && @recursive_that_map.has_key?(instance.object_id)
  end

  # Add the given argument as 'this' invoke the given block with the resulting state
  # @param instance [Object] the instance to add
  # @return [Object] the result of yielding
  def with_this(instance)
    if (@state & SELF_RECURSION_IN_THIS) == 0
      tc = this_count
      @state = @state | SELF_RECURSION_IN_THIS if this_put(instance)
      if tc < this_count
        # recursive state detected
        result = yield(@state)

        # pop state
        @state &= ~SELF_RECURSION_IN_THIS
        @this_map.delete(instance.object_id)
        return result
      end
    end
    yield(@state)
  end

  # Add the given argument as 'that' invoke the given block with the resulting state
  # @param instance [Object] the instance to add
  # @return [Object] the result of yielding
  def with_that(instance)
    if (@state & SELF_RECURSION_IN_THAT) == 0
      tc = that_count
      @state = @state | SELF_RECURSION_IN_THAT if that_put(instance)
      if tc < that_count
        # recursive state detected
        result = yield(@state)

        # pop state
        @state &= ~SELF_RECURSION_IN_THAT
        @that_map.delete(instance.object_id)
        return result
      end
    end
    yield(@state)
  end

  # Add the given argument as 'this' and return the resulting state
  # @param instance [Object] the instance to add
  # @return [Integer] the resulting state
  def add_this(instance)
    if (@state & SELF_RECURSION_IN_THIS) == 0
      @state = @state | SELF_RECURSION_IN_THIS if this_put(instance)
    end
    @state
  end

  # Add the given argument as 'that' and return the resulting state
  # @param instance [Object] the instance to add
  # @return [Integer] the resulting state
  def add_that(instance)
    if (@state & SELF_RECURSION_IN_THAT) == 0
      @state = @state | SELF_RECURSION_IN_THAT if that_put(instance)
    end
    @state
  end

  # @return the number of objects added to the `this` map
  def this_count
    instance_variable_defined?(:@this_map) ? @this_map.size : 0
  end

  # @return the number of objects added to the `that` map
  def that_count
    instance_variable_defined?(:@that_map) ? @that_map.size : 0
  end

  private

  def this_put(o)
    id = o.object_id
    @this_map ||= {}
    if @this_map.has_key?(id)
      @recursive_this_map ||= {}
      @recursive_this_map[id] = true
      true
    else
      @this_map[id] = true
      false
    end
  end

  def that_put(o)
    id = o.object_id
    @that_map ||= {}
    if @that_map.has_key?(id)
      @recursive_that_map ||= {}
      @recursive_that_map[id] = true
      true
    else
      @that_map[id] = true
      false
    end
  end
end
end
end
