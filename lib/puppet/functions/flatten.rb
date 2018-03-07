# Returns a flat Array produced from its possibly deeply nested given arguments.
#
# One or more arguments of any data type can be given to this function.
# The result is always a flat array representation where any nested arrays are recursively flattened.
#
# @example Typical use of `flatten()`
#
# ```puppet
# flatten(['a', ['b', ['c']]])
# # Would return: ['a','b','c']
# ```
#
# To flatten other kinds of iterables (for example hashes, or intermediate results like from a `reverse_each`)
# first convert the result to an array using `Array($x)`, or `$x.convert_to(Array)`. See the `new` function
# for details and options when performing a conversion.
#
# @example Flattening a Hash
#
# ```puppet
# $hsh = { a => 1, b => 2}
#
# # -- without conversion
# $hsh.flatten()
# # Would return [{a => 1, b => 2}]
#
# # -- with conversion
# $hsh.convert_to(Array).flatten()
# # Would return [a,1,b,2]
#
# flatten(Array($hsh))
# # Would also return [a,1,b,2]
# ```
#
# @example Flattening and concatenating at the same time
#
# ```puppet
# $a1 = [1, [2, 3]]
# $a2 = [[4,[5,6]]
# $x = 7
# flatten($a1, $a2, $x)
# # would return [1,2,3,4,5,6,7]
# ```
#
# @example Transforming to Array if not already an Array
#
# ```puppet
# flatten(42)
# # Would return [42]
#
# flatten([42])
# # Would also return [42]
# ```
#
# @since 5.5.0 support for flattening and concatenating at the same time
#
Puppet::Functions.create_function(:flatten) do
  dispatch :flatten_args do
    repeated_param 'Any', :args
  end

  def flatten_args(*args)
    args.flatten()
  end
end
