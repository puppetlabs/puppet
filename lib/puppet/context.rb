module Puppet::Context
  require 'puppet/context/trusted_information'

  class UndefinedBindingError < Puppet::Error; end
  class StackUnderflow < Puppet::Error; end

  # @api private
  class Bindings
    attr_reader :parent

    def initialize(parent, overrides = {})
      overrides ||= {}
      @parent = parent
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

  @bindings = Bindings.new(nil)

  # @param overrides [Hash] A hash of bindings to be merged with the parent context.
  # @api private
  def self.push(overrides)
    @bindings = Bindings.new(@bindings, overrides)
  end

  # @api private
  def self.pop
    raise(StackUnderflow, "Attempted to pop, but lready at root of the context stack.") if @bindings.root?
    @bindings = @bindings.parent
  end

  # Lookup a binding by name or return a default value provided by a passed block (if given).
  # @api public
  def self.lookup(name, &block)
    @bindings.lookup(name, block)
  end

  # @param bindings [Hash] A hash of bindings to be merged with the parent context.
  # @yield [] A block executed in the context of the temporarily pushed bindings.
  # @api public
  def self.override(bindings)
    push(bindings)

    yield
  ensure
    pop
  end
end
