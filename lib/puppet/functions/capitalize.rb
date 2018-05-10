# Capitalizes the first character of a String, or the first character of every String in an Iterable value (such as an Array).
#
# This function is compatible with the stdlib function with the same name.
#
# The function does the following:
# * For a `String`, a string with its first character in upper case version is returned. 
#   This is done using Ruby system locale which handles some, but not all
#   special international up-casing rules (for example German double-s ß is capitalized to "Ss").
# * For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is capitalized and the conversion is not recursive.
# * If the value is `Numeric` it is simply returned (this is for backwards compatibility).
# * An error is raised for all other data types.
#
# Please note: This function relies directly on Ruby's String implementation and as such may not be entirely UTF8 compatible.
# To ensure best compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.
#
# @example Capitalizing a String
# ```puppet
# 'hello'.capitalize()
# upcase('hello')
# ```
# Would both result in "Hello"
#
# @example Capitalizing strings in an Array
# ```puppet
# ['abc', 'bcd'].capitalize()
# capitalize(['abc', 'bcd'])
# ```
# Would both result in ['Abc', 'Bcd']
#
Puppet::Functions.create_function(:capitalize) do

  dispatch :on_numeric do
    param 'Numeric', :arg
  end

  dispatch :on_string do
    param 'String', :arg
  end

  dispatch :on_iterable do
    param 'Iterable[Variant[String, Numeric]]', :arg
  end

  # unit function - since the old implementation skipped Numeric values
  def on_numeric(n)
    n
  end

  def on_string(s)
    s.capitalize
  end

  def on_iterable(a)
    a.map {|x| do_capitalize(x) }
  end

  def do_capitalize(x)
    # x can only be a String or Numeric because type constraints have been automatically applied
    x.is_a?(String) ? x.capitalize : x
  end
end
