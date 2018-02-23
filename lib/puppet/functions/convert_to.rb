# The `convert_to(value, type)` is a convenience function that serves the same purpose as `new(type, value)`.
# The different argument ordering allows it to be used in chained style for
# improved readability from left to right.
#
# When this function is given a lambda, Puppet calls it with the converted value, and the function
# returns what the lambda returns. Otherwise, Puppet returns the converted value.
#
# @example 'convert_to' instead of 'new'
#
# ``` puppet
#   # Using 'convert_to()' explicitly
#   "abc".convert_to(Array).map |$i,$v| { [$i, $v] }.convert_to(Hash)
#   # Calling a type with the () operator
#   Hash(Array("abc").map |$i,$v| { [$i, $v] })
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
