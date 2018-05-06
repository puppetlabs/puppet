# Converts a String, Array or Hash (recursively) into upper case.
#
# This function is compatible with the stdlib function with the same name.
#
# The function does the following:
# * For a `String`, its upper case version is returned. This is done using Ruby system locale which handles some, but not all
#   special international up-casing rules (for example German double-s ß is upcased to "SS", whereas upper case double-s
#   is downcased to ß).
# * For `Array` and `Hash` the conversion to upper case is recursive and each key and value must be convertible by
#   this function.
# * When a `Hash` is converted, some keys could result in the same key - in those cases, the
#   latest key-value wins. For example if keys "aBC", and "abC" where both present, after upcase there would only be one
#   key "ABC".
# * If the value is `Numeric` it is simply returned (this is for backwards compatibility).
# * An error is raised for all other data types.
#
# Please note: This function relies directly on Ruby's String implementation and as such may not be entirely UTF8 compatible.
# To ensure best compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.
#
# @example Converting a String to upper case
# ```puppet
# 'hello'.upcase()
# upcase('hello')
# ```
# Would both result in "HELLO"
#
# @example Converting an Array to upper case
# ```puppet
# ['a', 'b'].upcase()
# upcase(['a', 'b'])
# ```
# Would both result in ['A', 'B']
#
# @example Converting a Hash to upper case
# ```puppet
# {'a' => 'hello', 'b' => 'goodbye'}.upcase()
# ```
# Would result in `{'A' => 'HELLO', 'B' => 'GOODBYE'}`
#
# @example Converting a recursive structure
# ```puppet
# ['a', 'b', ['c', ['d']], {'x' => 'y'}].upcase
# ```
# Would result in `['A', 'B', ['C', ['D']], {'X' => 'Y'}]`
#
Puppet::Functions.create_function(:upcase) do
  local_types do
    type 'StringData = Variant[String, Numeric, Array[StringData], Hash[StringData, StringData]]'
  end

  dispatch :on_numeric do
    param 'Numeric', :arg
  end

  dispatch :on_string do
    param 'String', :arg
  end

  dispatch :on_array do
    param 'Array[StringData]', :arg
  end

  dispatch :on_hash do
    param 'Hash[StringData, StringData]', :arg
  end

  # unit function - since the old implementation skipped Numeric values
  def on_numeric(n)
    n
  end

  def on_string(s)
    s.upcase
  end

  def on_array(a)
    a.map {|x| do_upcase(x) }
  end

  def on_hash(h)
    result = {}
    h.each_pair {|k,v| result[do_upcase(k)] = do_upcase(v) }
    result
  end

  def do_upcase(x)
    x.is_a?(String) ? x.upcase : call_function('upcase', x)
  end
end
