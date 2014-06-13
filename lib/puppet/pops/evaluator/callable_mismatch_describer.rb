# @api private
module Puppet::Pops::Evaluator::CallableMismatchDescriber
  # Produces a string with the difference between the given arguments and support signature(s).
  #
  # @param name [String] The name of the callable to describe
  # @param args_type [Puppet::Pops::Types::Tuple] The tuple of argument types.
  # @param supported_signatures [Array<Puppet::Pops::Types::Callable>] The available signatures that were available for calling.
  #
  # @api private
  def self.diff_string(name, args_type, supported_signatures)
    result = [ ]
    if supported_signatures.size == 1
      signature = supported_signatures[0]
      params_type  = signature.type.param_types
      block_type   = signature.type.block_type
      params_names = signature.parameter_names
      result << "expected:\n  #{name}(#{signature_string(signature)}) - #{arg_count_string(signature.type)}"
    else
      result << "expected one of:\n"
      result << supported_signatures.map do |signature|
        params_type = signature.type.param_types
        "  #{name}(#{signature_string(signature)}) - #{arg_count_string(signature.type)}"
      end.join("\n")
    end

    result << "\nactual:\n  #{name}(#{arg_types_string(args_type)}) - #{arg_count_string(args_type)}"

    result.join('')
  end

  private

  # Produces a string for the signature(s)
  #
  # @api private
  def self.signature_string(signature)
    param_types  = signature.type.param_types
    block_type   = signature.type.block_type
    param_names = signature.parameter_names

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
    case signature.type.block_type
    when Puppet::Pops::Types::POptionalType
      result << ', ' unless result == ''
      result << "#{tc.string(signature.type.block_type.optional_type)} #{signature.block_name} {0,1}"
    when Puppet::Pops::Types::PCallableType
      result << ', ' unless result == ''
      result << "#{tc.string(signature.type.block_type)} #{signature.block_name}"
    when NilClass
      # nothing
    end
    result
  end

  # Why oh why Ruby do you not have a standard Math.max ?
  # @api private
  def self.max(a, b)
    a >= b ? a : b
  end

  # @api private
  def self.opt_value_indicator(index, required_count, limit)
    count = index + 1
    (count > required_count && count < limit) ? '?' : ''
  end

  # @api private
  def self.arg_count_string(args_type)
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
  def self.arg_types_string(args_type)
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
  def self.range_string(size_range, squelch_one = true)
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
