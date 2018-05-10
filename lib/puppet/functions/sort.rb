# Sorts an Array numerically or lexicographically or the characters of a String lexicographically.
# Please note: This function is based on Ruby String comparison and as such may not be entirely UTF8 compatible.
# To ensure compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.
#
# This function is compatible with the function sort() in stdlib.
# * Comparison of characters in a string always uses a system locale and may not be what is expected for a particular locale
# * Sorting is based on Ruby's <=> operator unless a lambda is given that performs the comparison.
#   * comparison of strings is case dependent (use lambda with `compare($a,$b)` to ignore case)
#   * comparison of mixed data types raises an error (if there is the need to sort mixed data types use a lambda)
#
# Also see the `compare()` function for information about comparable data types in general.
#
# @example Sorting a String
#
# ```puppet
# notice(sort("xadb")) # notices 'abdx'
# ```
#
# @example Sorting an Array
#
# ```puppet
# notice(sort([3,6,2])) # notices [2, 3, 6]
# ```
#
# @example Sorting with a lambda
#
# ```puppet
# notice(sort([3,6,2]) |$a,$b| { compare($a, $b) }) # notices [2, 3, 6]
# notice(sort([3,6,2]) |$a,$b| { compare($b, $a) }) # notices [6, 3, 2]
# ```
#
# @example Case independent sorting with a lambda
#
# ```puppet
# notice(sort(['A','b','C']))                                    # notices ['A', 'C', 'b']
# notice(sort(['A','b','C']) |$a,$b| { compare($a, $b) })        # notices ['A', 'b', 'C']
# notice(sort(['A','b','C']) |$a,$b| { compare($a, $b, true) })  # notices ['A', 'b', 'C']
# notice(sort(['A','b','C']) |$a,$b| { compare($a, $b, false) }) # notices ['A','C', 'b']
# ```
#
# @example Sorting Array with Numeric and String so that numbers are before strings
#
# ```puppet
# notice(sort(['b', 3, 'a', 2]) |$a, $b| {
#   case [$a, $b] {
#     [String, Numeric] : { 1 }
#     [Numeric, String] : { -1 }
#     default:            { compare($a, $b) }
#   }
# })
# ```
# Would notice [2,3,'a','b']
#
# @since 6.0.0 - supporting a lambda to do compare
#
Puppet::Functions.create_function(:sort) do
  dispatch :sort_string do
    param 'String', :string_value
    optional_block_param 'Callable[2,2]', :block
  end

  dispatch :sort_array do
    param 'Array', :array_value
    optional_block_param 'Callable[2,2]', :block
  end

  def sort_string(s, &block)
    sort_array(s.split(''), &block).join('')
  end

  def sort_array(a, &block)
    a.sort(&block)
  end
end
