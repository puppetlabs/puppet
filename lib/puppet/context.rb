# frozen_string_literal: true

require_relative '../puppet/thread_local'

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
  require_relative 'context/trusted_information'

  class UndefinedBindingError < Puppet::Error; end
  class StackUnderflow < Puppet::Error; end

  class UnknownRollbackMarkError < Puppet::Error; end
  class DuplicateRollbackMarkError < Puppet::Error; end

  # @api private
  def initialize(initial_bindings)
    @stack = Puppet::ThreadLocal.new(EmptyStack.new.push(initial_bindings))

    # By initializing @rollbacks to nil and creating a hash lazily when #mark or
    # #rollback are called we ensure that the hashes are never shared between
    # threads and it's safe to mutate them
    @rollbacks = Puppet::ThreadLocal.new(nil)
  end

  # @api private
  def push(overrides, description = '')
    @stack.value = @stack.value.push(overrides, description)
  end

  # Push a context and make this global across threads
  # Do not use in a context where multiple threads may already exist
  #
  # @api private
  def unsafe_push_global(overrides, description = '')
    @stack = Puppet::ThreadLocal.new(
      @stack.value.push(overrides, description)
    )
  end

  # @api private
  def pop
    @stack.value = @stack.value.pop
  end

  # @api private
  def lookup(name, &block)
    @stack.value.lookup(name, &block)
  end

  # @api private
  def override(bindings, description = '', &block)
    saved_point = @stack.value
    push(bindings, description)

    yield
  ensure
    @stack.value = saved_point
  end

  # Mark a place on the context stack to later return to with {rollback}.
  #
  # @param name [Object] The identifier for the mark
  #
  # @api private
  def mark(name)
    @rollbacks.value ||= {}
    if @rollbacks.value[name].nil?
      @rollbacks.value[name] = @stack.value
    else
      raise DuplicateRollbackMarkError, _("Mark for '%{name}' already exists") % { name: name }
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
    @rollbacks.value ||= {}
    if @rollbacks.value[name].nil?
      raise UnknownRollbackMarkError, _("Unknown mark '%{name}'") % { name: name }
    end

    @stack.value = @rollbacks.value.delete(name)
  end

  # Base case for Puppet::Context::Stack.
  #
  # @api private
  class EmptyStack
    # Lookup a binding. Since there are none in EmptyStack, this always raises
    # an exception unless a block is passed, in which case the block is called
    # and its return value is used.
    #
    # @api private
    def lookup(name, &block)
      if block
        block.call
      else
        raise UndefinedBindingError, _("Unable to lookup '%{name}'") % { name: name }
      end
    end

    # Base case of #pop always raises an error since this is the bottom
    #
    # @api private
    def pop
      raise(StackUnderflow,
            _('Attempted to pop, but already at root of the context stack.'))
    end

    # Push bindings onto the stack by creating a new Stack object with `self` as
    # the parent
    #
    # @api private
    def push(overrides, description = '')
      Puppet::Context::Stack.new(self, overrides, description)
    end

    # Return the bindings table, which is always empty here
    #
    # @api private
    def bindings
      {}
    end
  end

  # Internal implementation of the bindings stack used by Puppet::Context. An
  # instance of Puppet::Context::Stack represents one level of bindings. It
  # caches a merged copy of all the bindings in the stack up to this point.
  # Each element of the stack is immutable, allowing the base to be shared
  # between threads.
  #
  # @api private
  class Stack
    attr_reader :bindings

    def initialize(parent, bindings, description = '')
      @parent = parent
      @bindings = parent.bindings.merge(bindings || {})
      @description = description
    end

    # Lookup a binding in the current stack. Return the value if it is present.
    # If the value is a stored Proc, evaluate, cache, and return the result. If
    # no binding is found and a block is passed evaluate it and return the
    # result. Otherwise an exception is raised.
    #
    # @api private
    def lookup(name, &block)
      if @bindings.include?(name)
        value = @bindings[name]
        value.is_a?(Proc) ? (@bindings[name] = value.call) : value
      elsif block
        block.call
      else
        raise UndefinedBindingError,
              _("Unable to lookup '%{name}'") % { name: name }
      end
    end

    # Pop one level off the stack by returning the parent object.
    #
    # @api private
    def pop
      @parent
    end

    # Push bindings onto the stack by creating a new Stack object with `self` as
    # the parent
    #
    # @api private
    def push(overrides, description = '')
      Puppet::Context::Stack.new(self, overrides, description)
    end
  end
end
