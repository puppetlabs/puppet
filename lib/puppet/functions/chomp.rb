# Returns a new string with the record separator character(s) removed.
# The record separator is the line ending characters `\r` and `\n`.
#
# This function is compatible with the stdlib function with the same name.
#
# The function does the following:
# * For a `String` the conversion removes `\r\n`, `\n` or `\r` from the end of a string.
# * For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is processed and the conversion is not recursive.
# * If the value is `Numeric` it is simply returned (this is for backwards compatibility).
# * An error is raised for all other data types.
#
# @example Removing line endings
# ```puppet
# "hello\r\n".chomp()
# chomp("hello\r\n")
# ```
# Would both result in `"hello"`
#
# @example Removing line endings in an array
# ```puppet
# ["hello\r\n", "hi\r\n"].chomp()
# chomp(["hello\r\n", "hi\r\n"])
# ```
# Would both result in `['hello', 'hi']`
#
Puppet::Functions.create_function(:chomp) do

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
    s.chomp
  end

  def on_iterable(a)
    a.map {|x| do_chomp(x) }
  end

  def do_chomp(x)
    # x can only be a String or Numeric because type constraints have been automatically applied
    x.is_a?(String) ? x.chomp : x
  end
end
