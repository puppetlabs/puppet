# Joins the values of an Array into a string with elements separated by a delimiter.
#
# Supports up to two arguments
# * **values** - first argument is required and must be an an `Array`
# * **delimiter** - second arguments is the delimiter between elements, must be a `String` if given, and defaults to an empty string.
#
# @example Typical use of `join`
#
# ```puppet
# join(['a','b','c'], ",")
# # Would result in: "a,b,c"
# ```
#
# Note that array is flattened before elements are joined, but flattening does not extend to arrays nested in hashes or other objects.
#
# @example Arrays nested in hashes are not joined
#
# ```puppet
# $a = [1,2, undef, 'hello', [x,y,z], {a => 2, b => [3, 4]}]
# notice join($a, ', ')
#
# # would result in noticing:
# # 1, 2, , hello, x, y, z, {"a"=>2, "b"=>[3, 4]}
# ```
#
# For joining iterators and other containers of elements a conversion must first be made to
# an `Array`. The reason for this is that there are many options how such a conversion should
# be made.
#
# @example Joining the result of a reverse_each converted to an array
# 
# ```puppet
# [1,2,3].reverse_each.convert_to(Array).join(', ')
# # would result in: "3, 2, 1"
# ```
# @example Joining a hash
#
# ```puppet
# {a => 1, b => 2}.convert_to(Array).join(', ')
# # would result in "a, 1, b, 2"
# ```
#
# For more detailed control over the formatting (including indentations and line breaks, delimiters around arrays
# and hash entries, between key/values in hash entries, and individual formatting of values in the array)
# see the `new` function for `String` and its formatting options for `Array` and `Hash`.
#
Puppet::Functions.create_function(:join) do
  dispatch :join do
    param 'Array', :arg
    optional_param 'String', :delimiter
  end

  def join(arg, delimiter = '', puppet_formatting = false)
      arg.join(delimiter)
  end
end
