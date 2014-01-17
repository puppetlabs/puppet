# Puppet::Context is a system for tracking services and contextual information
# that puppet needs to be able to run. Values are "bound" in a context when it is created
# and cannot be changed; however a child context can be created, using
# {#override}, that provides a different value.
#
# @api private
class Puppet::Context
  require 'puppet/context/trusted_information'

  class UndefinedBindingError < Puppet::Error; end
  class StackUnderflow < Puppet::Error; end

  # @api private
  class Bindings
    attr_reader :parent, :description

    def initialize(parent, description, overrides = {})
      overrides ||= {}
      @parent = parent
      @description = description
      @table = parent ? parent.table.merge(overrides) : overrides
    end

    def lookup(name, default_proc)
      if @table.include?(name)
        @table[name]
      elsif default_proc
        default_proc.call
      else
        raise UndefinedBindingError, name
      end
    end

    def root?
      @parent.nil?
    end

    protected

    attr_reader :table
  end

  # @api private
  def initialize(initial_bindings)
    @bindings = Bindings.new(nil, "root", initial_bindings)
  end

  # @api private
  def push(overrides, description = "")
    @bindings = Bindings.new(@bindings, description, overrides)
  end

  # @api private
  def pop
    raise(StackUnderflow, "Attempted to pop, but already at root of the context stack.") if @bindings.root?
    @bindings = @bindings.parent
  end

  # @api private
  def lookup(name, &block)
    @bindings.lookup(name, block)
  end

  # @api private
  def override(bindings, description = "", &block)
    push(bindings, description)

    yield
  ensure
    pop
  end
end
