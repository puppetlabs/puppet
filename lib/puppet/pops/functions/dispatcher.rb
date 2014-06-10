# Evaluate the dispatches defined as {Puppet::Pops::Functions::Dispatch}
# instances to call the appropriate method on the
# {Puppet::Pops::Functions::Function} instance.
#
# @api private
class Puppet::Pops::Functions::Dispatcher
  attr_reader :dispatchers

  # @api private
  def initialize()
    @dispatchers = [ ]
  end

  # Answers if dispatching has been defined
  # @return [Boolean] true if dispatching has been defined
  #
  # @api private
  def empty?
    @dispatchers.empty?
  end

  # Dispatches the call to the first found signature (entry with matching type).
  #
  # @param instance [Puppet::Functions::Function] - the function to call
  # @param calling_scope [T.B.D::Scope] - the scope of the caller
  # @param args [Array<Object>] - the given arguments in the form of an Array
  # @return [Object] - what the called function produced
  #
  # @api private
  def dispatch(instance, calling_scope, args)
    tc = Puppet::Pops::Types::TypeCalculator
    actual = tc.infer_set(args)
    found = @dispatchers.find { |d| tc.callable?(d.type, actual) }
    if found
      found.invoke(instance, calling_scope, args)
    else
      raise ArgumentError, "function '#{instance.class.name}' called with mis-matched arguments\n#{Puppet::Pops::Evaluator::CallableMismatchDescriber.diff_string(instance.class.name, actual, @dispatchers)}"
    end
  end

  # Adds a regular dispatch for one method name
  #
  # @param type [Puppet::Pops::Types::PArrayType, Puppet::Pops::Types::PTupleType] - type describing signature
  # @param method_name [String] - the name of the method that will be called when type matches given arguments
  # @param names [Array<String>] - array with names matching the number of parameters specified by type (or empty array)
  #
  # @api private
  def add_dispatch(type, method_name, param_names, block_name, injections, weaving, last_captures)
    @dispatchers << Puppet::Pops::Functions::Dispatch.new(type, method_name, param_names, block_name, injections, weaving, last_captures)
  end

  # Produces a CallableType for a single signature, and a Variant[<callables>] otherwise
  #
  # @api private
  def to_type()
    # make a copy to make sure it can be contained by someone else (even if it is not contained here, it
    # should be treated as immutable).
    #
    callables = dispatchers.map { | dispatch | dispatch.type.copy }

    # multiple signatures, produce a Variant type of Callable1-n (must copy them)
    # single signature, produce single Callable
    callables.size > 1 ?  Puppet::Pops::Types::TypeFactory.variant(*callables) : callables.pop
  end

  # @api private
  def signatures
    @dispatchers
  end
end
