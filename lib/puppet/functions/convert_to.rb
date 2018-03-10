# The `convert_to(value, type)` is a convenience function that does the same as `new(type, value)`.
# The difference in the argument ordering allows it to be used in chained style for
# improved readability "left to right".
#
# When the function is given a lambda, it is called with the converted value, and the function
# returns what the lambda returns, otherwise the converted value.
#
# @example 'convert_to' instead of 'new'
#
# ```puppet
#   # The harder to read variant:
#   # Using new operator - that is "calling the type" with operator ()
#   Hash(Array("abc").map |$i,$v| { [$i, $v] })
#
#   # The easier to read variant:
#   # using 'convert_to'
#   "abc".convert_to(Array).map |$i,$v| { [$i, $v] }.convert_to(Hash)
# ```
#
# @since 5.4.0
#
Puppet::Functions.create_function(:convert_to) do
  dispatch :convert_to do
    param 'Any', :value
    param 'Type', :type
    optional_block_param 'Callable[1,1]', :block
  end

  def convert_to(value, type, &block)
    result = call_function('new', type, value)
    block_given? ? yield(result) : result
  end
end
