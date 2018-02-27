# Returns `true` if the given argument is an empty collection of values.
#
# This function can answer if one of the following is empty:
# * `Array`, `Hash` - having zero entries
# * `String`, `Binary` - having zero length
# * `Numeric` - for backwards compatibility with the stdlib function with the same name,
#   a result of `false` is returned for all `Numeric` values instead of raising an error.
#   This may be changed in a future release of puppet.
#
# @example Using `empty`
#
# ```puppet
# notice([].empty)
# notice(empty([]))
# # would both notice 'true'
# ```
#
# @since Puppet 5.5.0 - support for Binary
#
Puppet::Functions.create_function(:empty) do
  dispatch :collection_empty do
    param 'Collection', :coll
  end

  dispatch :string_empty do
    param 'String', :str
  end

  dispatch :numeric_empty do
    param 'Numeric', :num
  end

  dispatch :binary_empty do
    param 'Binary', :bin
  end

  def collection_empty(coll)
    coll.empty?
  end

  def string_empty(str)
    str.empty?
  end

  # For compatibility reasons - return false rather than error on floats and integers
  # (Yes, it is strange)
  #
  def numeric_empty(num)
    false
  end

  def binary_empty(bin)
    bin.length == 0
  end

end
