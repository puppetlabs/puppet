# Returns the values of a hash as an Array
#
# @example Using `values`
#
# ```puppet
# $hsh = {"apples" => 3, "oranges" => 4 }
# $hsh.values()
# values($hsh)
# # both results in the array [3, 4]
# ```
#
# * Note that a hash in the puppet language accepts any data value (including `undef`) unless
#   it is constrained with a `Hash` data type that narrows the allowed data types.
# * For an empty hash, an empty array is returned.
# * The order of the values is the same as the order in the hash (typically the order in which they were added).
#
Puppet::Functions.create_function(:values) do
  dispatch :values do
    param 'Hash', :hsh
  end

  def values(hsh)
    hsh.values
  end
end
