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
      raise ArgumentError, "function '#{instance.class.name}' called with mis-matched arguments\n#{diff_string(instance.class.name, actual)}"
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

  private

  # Produces a string with the difference between the given arguments and support signature(s).
  #
  # @api private
  def diff_string(name, args_type)
    result = [ ]
    if @dispatchers.size < 2
      dispatch = @dispatchers[ 0 ]
      params_type  = dispatch.type.param_types
      block_type   = dispatch.type.block_type
      params_names = dispatch.param_names
      result << "expected:\n  #{name}(#{signature_string(dispatch)}) - #{arg_count_string(dispatch.type)}"
    else
      result << "expected one of:\n"
      result << (@dispatchers.map do |d|
        params_type = d.type.param_types
        "  #{name}(#{signature_string(d)}) - #{arg_count_string(d.type)}"
      end.join("\n"))
    end
    result << "\nactual:\n  #{name}(#{arg_types_string(args_type)}) - #{arg_count_string(args_type)}"
    result.join('')
  end

  # Produces a string for the signature(s)
  #
  # @api private
  def signature_string(dispatch) # args_type, param_names
    param_types  = dispatch.type.param_types
    block_type   = dispatch.type.block_type
    param_names = dispatch.param_names

    from, to = param_types.size_range
    if from == 0 && to == 0
      # No parameters function
      return ''
    end

    required_count = from
    # there may be more names than there are types, and count needs to be subtracted from the count
    # to make it correct for the last named element
    adjust = max(0, param_names.size() -1)
    last_range = [max(0, (from - adjust)), (to - adjust)]

    types =
    case param_types
    when Puppet::Pops::Types::PTupleType
      param_types.types
    when Puppet::Pops::Types::PArrayType
      [ param_types.element_type ]
    end
    tc = Puppet::Pops::Types::TypeCalculator

    # join type with names (types are always present, names are optional)
    # separate entries with comma
    #
    result =
    if param_names.empty?
      types.each_with_index.map {|t, index| tc.string(t) + opt_value_indicator(index, required_count, 0) }
    else
      limit = param_names.size
      result = param_names.each_with_index.map do |name, index|
        [tc.string(types[index] || types[-1]), name].join(' ') + opt_value_indicator(index, required_count, limit)
      end
    end.join(', ')

    # Add {from, to} for the last type
    # This works for both Array and Tuple since it describes the allowed count of the "last" type element
    # for both. It does not show anything when the range is {1,1}.
    #
    result += range_string(last_range)

    # If there is a block, include it with its own optional count {0,1}
    case dispatch.type.block_type
    when Puppet::Pops::Types::POptionalType
      result << ', ' unless result == ''
      result << "#{tc.string(dispatch.type.block_type.optional_type)} #{dispatch.block_name} {0,1}"
    when Puppet::Pops::Types::PCallableType
      result << ', ' unless result == ''
      result << "#{tc.string(dispatch.type.block_type)} #{dispatch.block_name}"
    when NilClass
      # nothing
    end
    result
  end

  # Why oh why Ruby do you not have a standard Math.max ?
  # @api private
  def max(a, b)
    a >= b ? a : b
  end

  # @api private
  def opt_value_indicator(index, required_count, limit)
    count = index + 1
    (count > required_count && count < limit) ? '?' : ''
  end

  # @api private
  def arg_count_string(args_type)
    if args_type.is_a?(Puppet::Pops::Types::PCallableType)
      size_range = args_type.param_types.size_range # regular parameters
      adjust_range=
      case args_type.block_type
      when Puppet::Pops::Types::POptionalType
        size_range[1] += 1
      when Puppet::Pops::Types::PCallableType
        size_range[0] += 1
        size_range[1] += 1
      when NilClass
        # nothing
      else
        raise ArgumentError, "Internal Error, only nil, Callable, and Optional[Callable] supported by Callable block type"
      end
    else
      size_range = args_type.size_range
    end
    "arg count #{range_string(size_range, false)}"
  end

  # @api private
  def arg_types_string(args_type)
    types =
    case args_type
    when Puppet::Pops::Types::PTupleType
      last_range = args_type.repeat_last_range
      args_type.types
    when Puppet::Pops::Types::PArrayType
      last_range = args_type.size_range
      [ args_type.element_type ]
    end
    # stringify generalized versions or it will display Integer[10,10] for "10", String['the content'] etc.
    # note that type must be copied since generalize is a mutating operation
    tc = Puppet::Pops::Types::TypeCalculator
    result = types.map { |t| tc.string(tc.generalize!(t.copy)) }.join(', ')

    # Add {from, to} for the last type
    # This works for both Array and Tuple since it describes the allowed count of the "last" type element
    # for both. It does not show anything when the range is {1,1}.
    #
    result += range_string(last_range)
    result
  end

  # Formats a range into a string of the form: `{from, to}`
  #
  # The following cases are optimized:
  #
  #   * from and to are equal => `{from}`
  #   * from and to are both and 1 and squelch_one == true => `''`
  #   * from is 0 and to is 1 => `'?'`
  #   * to is INFINITY => `{from, }`
  #
  # @api private
  def range_string(size_range, squelch_one = true)
    from, to = size_range
    if from == to
      (squelch_one && from == 1) ? '' : "{#{from}}"
    elsif to == Puppet::Pops::Types::INFINITY
      "{#{from},}"
    elsif from == 0 && to == 1
      '?'
    else
      "{#{from},#{to}}"
    end
  end
end
