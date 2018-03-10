# Returns the length of an Array, Hash, String, or Binary value.
#
# The returned value is a positive integer indicating the number
# of elements in the container; counting (possibly multibyte) characters for a `String`,
# bytes in a `Binary`, number of elements in an `Array`, and number of
# key-value associations in a Hash.
#
# @example Using `length`
#
# ```puppet
# "roses".length()        # 5
# length("violets")       # 7
# [10, 20].length         # 2
# {a => 1, b => 3}.length # 2
# ```
#
# @since 5.5.0 - also supporting Binary
#
Puppet::Functions.create_function(:length) do
  dispatch :collection_length do
    param 'Collection', :arg
  end

  dispatch :string_length do
    param 'String', :arg
  end

  dispatch :binary_length do
    param 'Binary', :arg
  end

  def collection_length(col)
    col.size
  end

  def string_length(s)
    s.length
  end

  def binary_length(bin)
    bin.length
  end

end
