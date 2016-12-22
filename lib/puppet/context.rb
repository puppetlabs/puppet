# Puppet::Context is a system for tracking services and contextual information
# that puppet needs to be able to run. Values are "bound" in a context when it is created
# and cannot be changed; however a child context can be created, using
# {#override}, that provides a different value.
#
# When binding a {Proc}, the proc is called when the value is looked up, and the result
# is memoized for subsequent lookups. This provides a lazy mechanism that can be used to
# delay expensive production of values until they are needed.
#
# @api private
class Puppet::Context
  require 'puppet/context/trusted_information'

  class UndefinedBindingError < Puppet::Error; end
  class StackUnderflow < Puppet::Error; end

  class UnknownRollbackMarkError < Puppet::Error; end
  class DuplicateRollbackMarkError < Puppet::Error; end

  # @api private
  def initialize(initial_bindings)
    @table = initial_bindings
    @ignores = []
    @description = "root"
    @id = 0
    @rollbacks = {}
    @stack = [[0, nil, nil]]
  end

  # @api private
  def push(overrides, description = "")
    @id += 1
    @stack.push([@id, @table, @description])
    @table = @table.merge(overrides || {})
    @description = description
  end

  # @api private
  def pop
    if @stack[-1][0] == 0
      raise(StackUnderflow, "Attempted to pop, but already at root of the context stack.")
    else
      (_, @table, @description) = @stack.pop
    end
  end

  # @api private
  def lookup(name, &block)
    if @table.include?(name) && !@ignores.include?(name)
      value = @table[name]
      value.is_a?(Proc) ? (@table[name] = value.call) : value
    elsif block
      block.call
    else
      raise UndefinedBindingError, "no '#{name}' in #{@table.inspect} at top of #{@stack.inspect}"
    end
  end

  # @api private
  def override(bindings, description = "", &block)
    mark_point = "override over #{@stack[-1][0]}"
    mark(mark_point)
    push(bindings, description)

    yield
  ensure
    rollback(mark_point)
  end

  # @api private
  def ignore(name)
    @ignores << name
  end

  # @api private
  def restore(name)
    if @ignores.include?(name)
      @ignores.delete(name)
    else
      raise UndefinedBindingError, "no '#{name}' in ignores #{@ignores.inspect} at top of #{@stack.inspect}"
    end
  end

  # Mark a place on the context stack to later return to with {rollback}.
  #
  # @param name [Object] The identifier for the mark
  #
  # @api private
  def mark(name)
    if @rollbacks[name].nil?
      @rollbacks[name] = @stack[-1][0]
    else
      raise DuplicateRollbackMarkError, "Mark for '#{name}' already exists"
    end
  end

  # Roll back to a mark set by {mark}.
  #
  # Rollbacks can only reach a mark accessible via {pop}. If the mark is not on
  # the current context stack the behavior of rollback is undefined.
  #
  # @param name [Object] The identifier for the mark
  #
  # @api private
  def rollback(name)
    if @rollbacks[name].nil?
      raise UnknownRollbackMarkError, "Unknown mark '#{name}'"
    end

    while @stack[-1][0] != @rollbacks[name]
      pop
    end

    @rollbacks.delete(name)
  end
end
