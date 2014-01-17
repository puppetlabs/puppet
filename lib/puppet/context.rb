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

  # The bindings used for initialization of puppet
  # @api private
  def self.initial_context
    {
      :environments => Puppet::Environments::Legacy.new,
      :current_environment => Puppet::Node::Environment.root,
    }
  end

  # A simple set of bindings that is just enough to limp along to
  # initialization where the {#initial_context} bindings are put in place
  # @api private
  def self.bootstrap_context
    { :current_environment => Puppet::Node::Environment.create(:'*bootstrap*', [], '') }
  end

  # @param overrides [Hash] A hash of bindings to be merged with the parent context.
  # @param description [String] A description of the context.
  # @api private
  def self.push(overrides, description = "")
    @instance.push(overrides, description)
  end

  # Return to the previous context.
  # @raise [StackUnderflow] if the current context is the root
  # @api private
  def self.pop
    @instance.pop
  end

  # Lookup a binding by name or return a default value provided by a passed block (if given).
  # @api public
  def self.lookup(name, &block)
    @instance.lookup(name, &block)
  end

  # @param bindings [Hash] A hash of bindings to be merged with the parent context.
  # @param description [String] A description of the context.
  # @yield [] A block executed in the context of the temporarily pushed bindings.
  # @api public
  def self.override(bindings, description = "", &block)
    @instance.override(bindings, description, &block)
  end

  # The single instance used for normal operation
  @instance = new(bootstrap_context)
end
