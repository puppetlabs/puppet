# Returns the keys of a hash as an Array
#
# @example Using `keys`
#
# ```puppet
# $hsh = {"apples" => 3, "oranges" => 4 }
# $hsh.keys()
# keys($hsh)
# # both results in the array ["apples", "oranges"]
# ```
#
# * Note that a hash in the puppet language accepts any data value (including `undef`) unless
#   it is constrained with a `Hash` data type that narrows the allowed data types.
# * For an empty hash, an empty array is returned.
# * The order of the keys is the same as the order in the hash (typically the order in which they were added).
#
Puppet::Functions.create_function(:keys) do
  dispatch :keys do
    param 'Hash', :hsh
  end

  def keys(hsh)
    hsh.keys
  end
end
