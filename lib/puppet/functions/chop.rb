# Returns a new string with the last character removed.
# If the string ends with `\r\n`, both characters are removed. Applying chop to an empty
# string returns an empty string. If you wish to merely remove record
# separators then you should use the `chomp` function.
#
# This function is compatible with the stdlib function with the same name.
#
# The function does the following:
# * For a `String` the conversion removes the last character, or if it ends with \r\n` it removes both. If String is empty
#   an empty string is returned.
# * For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is processed and the conversion is not recursive.
# * If the value is `Numeric` it is simply returned (this is for backwards compatibility).
# * An error is raised for all other data types.
#
# @example Removing line endings
# ```puppet
# "hello\r\n".chop()
# chop("hello\r\n")
# ```
# Would both result in `"hello"`
#
# @example Removing last char
# ```puppet
# "hello".chop()
# chop("hello")
# ```
# Would both result in `"hell"`
#
# @example Removing last char in an array
# ```puppet
# ["hello\r\n", "hi\r\n"].chop()
# chop(["hello\r\n", "hi\r\n"])
# ```
# Would both result in `['hello', 'hi']`
#
Puppet::Functions.create_function(:chop) do

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
    s.chop
  end

  def on_iterable(a)
    a.map {|x| do_chop(x) }
  end

  def do_chop(x)
    # x can only be a String or Numeric because type constraints have been automatically applied
    x.is_a?(String) ? x.chop : x
  end
end
