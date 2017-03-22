# CallableSignature
# ===
# A CallableSignature describes how something callable expects to be called.
# Different implementation of this class are used for different types of callables.
#
# @api public
#
class Puppet::Pops::Evaluator::CallableSignature

  # Returns the names of the parameters as an array of strings. This does not include the name
  # of an optional block parameter.
  #
  # All implementations are not required to supply names for parameters. They may be used if present,
  # to provide user feedback in errors etc. but they are not authoritative about the number of
  # required arguments, optional arguments, etc.
  #
  # A derived class must implement this method.
  #
  # @return [Array<String>] - an array of names (that may be empty if names are unavailable)
  #
  # @api public
  #
  def parameter_names
    raise NotImplementedError.new
  end

  # Returns a PCallableType with the type information, required and optional count, and type information about
  # an optional block.
  #
  # A derived class must implement this method.
  #
  # @return [Puppet::Pops::Types::PCallableType]
  # @api public
  #
  def type
    raise NotImplementedError.new
  end

  # Returns the expected type for an optional block. The type may be nil, which means that the callable does
  # not accept a block. If a type is returned it is one of Callable, Optional[Callable], Variant[Callable,...],
  # or Optional[Variant[Callable, ...]]. The Variant type is used when multiple signatures are acceptable.
  # The Optional type is used when the block is optional.
  #
  # @return [Puppet::Pops::Types::PAnyType, nil] the expected type of a block given as the last parameter in a call.
  #
  # @api public
  #
  def block_type
    type.block_type
  end

  # Returns the name of the block parameter if the callable accepts a block.
  # @return [String] the name of the block parameter
  # A derived class must implement this method.
  # @api public
  #
  def block_name
    raise NotImplementedError.new
  end

  # Returns a range indicating the optionality of a block. One of [0,0] (does not accept block), [0,1] (optional
  # block), and [1,1] (block required)
  #
  # @return [Array(Integer, Integer)] the range of the block parameter
  #
  def block_range
    type.block_range
  end

  # Returns the range of required/optional argument values as an array of [min, max], where an infinite
  # end is given as Float::INFINITY. To test against infinity, use the infinity? method.
  #
  # @return [Array[Integer, Numeric]] - an Array with [min, max]
  #
  # @api public
  #
  def args_range
    type.size_range
  end

  # Returns true if the last parameter captures the rest of the arguments, with a possible cap, as indicated
  # by the `args_range` method.
  # A derived class must implement this method.
  #
  # @return [Boolean] true if last parameter captures the rest of the given arguments (up to a possible cap)
  # @api public
  #
  def last_captures_rest?
    raise NotImplementedError.new
  end

  # Returns true if the given x is infinity
  # @return [Boolean] true, if given value represents infinity
  #
  # @api public
  #
  def infinity?(x)
    x == Float::INFINITY
  end

  # @return [Boolean] true if this signature represents an argument mismatch, false otherwise
  #
  # @api private
  def argument_mismatch_handler?
    false
  end
end
