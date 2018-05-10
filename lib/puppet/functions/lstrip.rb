# Strips leading spaces from a String
#
# This function is compatible with the stdlib function with the same name.
#
# The function does the following:
# * For a `String` the conversion removes all leading ASCII white space characters such as space, tab, newline, and return.
#   It does not remove other space-like characters like hard space (Unicode U+00A0). (Tip, `/^[[:space:]]/` regular expression
#   matches all space-like characters).
# * For an `Iterable[Variant[String, Numeric]]` (for example an `Array`) each value is processed and the conversion is not recursive.
# * If the value is `Numeric` it is simply returned (this is for backwards compatibility).
# * An error is raised for all other data types.
#
# @example Removing leading space from a String
# ```puppet
# "\n\thello".lstrip()
# camelcase("\n\thello")
# ```
# Would both result in `"hello"`
#
# @example Removing leading space from strings in an Array
# ```puppet
# ["\n\thello", "\n\thi"].lstrip()
# lstrip(["\n\thello", "\n\thi"])
# ```
# Would both result in `['hello', 'hi']`
#
Puppet::Functions.create_function(:lstrip) do

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
    s.lstrip
  end

  def on_iterable(a)
    a.map {|x| do_lstrip(x) }
  end

  def do_lstrip(x)
    # x can only be a String or Numeric because type constraints have been automatically applied
    x.is_a?(String) ? x.lstrip : x
  end
end
