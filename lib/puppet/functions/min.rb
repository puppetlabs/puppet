# Returns the lowest value among a variable number of arguments.
# Takes at least one argument.
#
# This function is (with one exception) compatible with the stdlib function
# with the same name and performs deprecated type conversion before
# comparison as follows:
#
# * If a value converted to String is an optionally '-' prefixed,
#   string of digits, one optional decimal point, followed by optional
#   decimal digits - then the comparison is performed on the values
#   converted to floating point.
# * If a value is not considered convertible to float, it is converted
#   to a `String` and the comparison is a lexical compare where min is
#   the lexicographical earlier value.
# * A lexicographical compare is performed in a system locale - international
#   characters may therefore not appear in what a user thinks is the correct order.
# * The conversion rules apply to values in pairs - the rule must hold for both
#   values - a value may therefore be compared using different rules depending
#   on the "other value".
# * The returned result found to be the "lowest" is the original unconverted value.
#
# The above rules have been deprecated in Puppet 6.0.0 as they produce strange results when
# given values of mixed data types. In general, either convert values to be
# all `String` or all `Numeric` values before calling the function, or call the
# function with a lambda that performs type conversion and comparison. This because one
# simply cannot compare `Boolean` with `Regexp` and with any arbitrary `Array`, `Hash` or
# `Object` and getting a meaningful result.
#
# The one change in the function's behavior is when the function is given a single
# array argument. The stdlib implementation would return that array as the result where
# it now instead returns the max value from that array.
#
# @example 'min of values - stdlib compatible'
#
# ```puppet
# notice(min(1)) # would notice 1
# notice(min(1,2)) # would notice 1
# notice(min("1", 2)) # would notice 1
# notice(min("0777", 512)) # would notice 512, since "0777" is not converted from octal form
# notice(min(0777, 512)) # would notice 511, since 0777 is decimal 511
# notice(min('aa', 'ab')) # would notice 'aa'
# notice(min(['a'], ['b'])) # would notice ['a'], since "['a']" is before "['b']"
# ```
#
# @example find 'min' value in an array
#
# ```puppet
# $x = [1,2,3,4]
# notice(min(*$x)) # would notice 1
# ```
#
# @example find 'min' value in an array directly - since Puppet 6.0.0
#
# ```puppet
# $x = [1,2,3,4]
# notice(min($x)) # would notice 1
# notice($x.min) # would notice 1
# ```
# This example shows that a single array argument is used as the set of values
# as opposed to being a single returned value.
#
# When calling with a lambda, it must accept two variables and it must return
# one of -1, 0, or 1 depending on if first argument is before/lower than, equal to,
# or higher/after the second argument.
#
# @example 'min of values using a lambda'
#
# ```puppet
# notice(min("2", "10", "100") |$a, $b| { compare($a, $b) })
# ```
#
# Would notice "10" as lower since it is lexicographically lower/before the other values. Without the
# lambda the stdlib compatible (deprecated) behavior would have been to return "2" since number conversion kicks in.
#
Puppet::Functions.create_function(:min) do
  dispatch :on_numeric do
    repeated_param 'Numeric', :values
  end

  dispatch :on_string do
    repeated_param 'String', :values
  end

  dispatch :on_single_numeric_array do
    param 'Array[Numeric]', :values
    optional_block_param 'Callable[2,2]', :block
  end

  dispatch :on_single_string_array do
    param 'Array[String]', :values
    optional_block_param 'Callable[2,2]', :block
  end

  dispatch :on_single_any_array do
    param 'Array', :values
    optional_block_param 'Callable[2,2]', :block
  end

  dispatch :on_any_with_block do
    repeated_param 'Any', :values
    block_param 'Callable[2,2]', :block
  end

  dispatch :on_any do
    repeated_param 'Any', :values
  end


  # All are Numeric - ok now, will be ok later
  def on_numeric(*args)
    assert_arg_count(args)
    args.min
  end

  # All are String, may convert to numeric (which is deprecated)
  def on_string(*args)
    assert_arg_count(args)

    args.min do|a,b|
      if a.to_s =~ %r{\A^-?\d+([._eE]\d+)?\z} && b.to_s =~ %r{\A-?\d+([._eE]\d+)?\z}
        Puppet.warn_once('deprecations', 'min_function_numeric_coerce_string',
          _("The min() function's auto conversion of String to Numeric is deprecated - change to convert input before calling, or use lambda"))
        a.to_f <=> b.to_f
      else
        # case sensitive as in the stdlib function
        a <=> b
      end
    end
  end

  def on_any_with_block(*args, &block)
    args.min {|x,y| block.call(x,y) }
  end

  def on_single_numeric_array(array, &block)
    if block_given?
      on_any_with_block(*array, &block)
    else
      on_numeric(*array)
    end
  end

  def on_single_string_array(array, &block)
    if block_given?
      on_any_with_block(*array, &block)
    else
      on_string(*array)
    end
  end

  def on_single_any_array(array, &block)
    if block_given?
      on_any_with_block(*array, &block)
    else
      on_any(*array)
    end
  end

  # Mix of data types - while only some compares are actually bad it will deprecate
  # the entire call
  #
  def on_any(*args)
    assert_arg_count(args)
    args.min do |a, b|
      as = a.to_s
      bs = b.to_s
      if as =~ %r{\A^-?\d+([._eE]\d+)?\z} && bs =~ %r{\A-?\d+([._eE]\d+)?\z}
        Puppet.warn_once('deprecations', 'min_function_numeric_coerce_string',
          _("The min() function's auto conversion of String to Numeric is deprecated - change to convert input before calling, or use lambda"))
        a.to_f <=> b.to_f
      else
        Puppet.warn_once('deprecations', 'min_function_string_coerce_any',
          _("The min() function's auto conversion of Any to String is deprecated - change to convert input before calling, or use lambda"))
        as <=> bs
      end
    end
  end

  def assert_arg_count(args)
    raise(ArgumentError, 'min(): Wrong number of arguments need at least one') if args.empty?
  end
end
