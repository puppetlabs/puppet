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
  def dispatch(instance, calling_scope, args, &block)
    found = @dispatchers.find { |d| d.type.callable_with?(args, block) }
    unless found
      args_type = Puppet::Pops::Types::TypeCalculator.singleton.infer_set(block_given? ? args + [block] : args)
      raise ArgumentError, Puppet::Pops::Types::TypeMismatchDescriber.describe_signatures(instance.class.name, signatures, args_type)
    end

    if found.argument_mismatch_handler?
      msg = found.invoke(instance, calling_scope, args)
      raise ArgumentError, "'#{instance.class.name}' #{msg}"
    end

    catch(:next) do
      found.invoke(instance, calling_scope, args, &block)
    end
  end

  # Adds a dispatch directly to the set of dispatchers.
  # @api private
  def add(a_dispatch)
    @dispatchers << a_dispatch
  end

  # Produces a CallableType for a single signature, and a Variant[<callables>] otherwise
  #
  # @api private
  def to_type()
    # make a copy to make sure it can be contained by someone else (even if it is not contained here, it
    # should be treated as immutable).
    #
    callables = dispatchers.map { | dispatch | dispatch.type }

    # multiple signatures, produce a Variant type of Callable1-n (must copy them)
    # single signature, produce single Callable
    callables.size > 1 ?  Puppet::Pops::Types::TypeFactory.variant(*callables) : callables.pop
  end

  # @api private
  def signatures
    @dispatchers.reject { |dispatcher| dispatcher.argument_mismatch_handler? }
  end
end
