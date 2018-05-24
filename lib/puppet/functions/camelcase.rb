# Creates a Camel Case version of a String
#
# This function is compatible with the stdlib function with the same name.
#
# The function does the following:
# * For a `String` the conversion replaces all combinations of *_<char>* with an upcased version of the
#   character following the _.  This is done using Ruby system locale which handles some, but not all
#   special international up-casing rules (for example German double-s ß is upcased to "Ss").
# * For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is capitalized and the conversion is not recursive.
# * If the value is `Numeric` it is simply returned (this is for backwards compatibility).
# * An error is raised for all other data types.
# * The result will not contain any underscore characters.
#
# Please note: This function relies directly on Ruby's String implementation and as such may not be entirely UTF8 compatible.
# To ensure best compatibility please use this function with Ruby 2.4.0 or greater - https://bugs.ruby-lang.org/issues/10085.
#
# @example Camelcase a String
# ```puppet
# 'hello_friend'.camelcase()
# camelcase('hello_friend')
# ```
# Would both result in `"HelloFriend"`
#
# @example Camelcase of strings in an Array
# ```puppet
# ['abc_def', 'bcd_xyz'].capitalize()
# capitalize(['abc_def', 'bcd_xyz'])
# ```
# Would both result in `['AbcDef', 'BcdXyz']`
#
Puppet::Functions.create_function(:camelcase) do

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
    s.split('_').map {|x| x.capitalize }.join('')
  end

  def on_iterable(a)
    a.map {|x| do_camelcase(x) }
  end

  def do_camelcase(x)
    # x can only be a String or Numeric because type constraints have been automatically applied
    x.is_a?(String) ? on_string(x) : x
  end
end
