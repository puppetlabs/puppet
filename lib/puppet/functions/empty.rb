# Returns `true` if the given argument is an empty collection of values.
#
# This function can answer if one of the following is empty:
# * `Array`, `Hash` - having zero entries
# * `String`, `Binary` - having zero length
#
# For backwards compatibility with the stdlib function with the same name the
# following data types are also accepted by the function instead of raising an error.
# Using these is deprecated and will raise a warning:
#
# * `Numeric` - `false` is returned for all `Numeric` values.
# * `Undef` - `true` is returned for all `Undef` values.
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

  dispatch :undef_empty do
    param 'Undef', :x
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
    deprecation_warning_for('Numeric')
    false
  end

  def binary_empty(bin)
    bin.length == 0
  end

  # For compatibility reasons - return true rather than error on undef
  # (Yes, it is strange, but undef was passed as empty string in 3.x API)
  #
  def undef_empty(x)
    true
  end

  def deprecation_warning_for(arg_type)
    file, line = Puppet::Pops::PuppetStack.top_of_stack
    msg = _("Calling function empty() with %{arg_type} value is deprecated.") % { arg_type: arg_type }
    Puppet.warn_once('deprecations', "empty-from-#{file}-#{line}", msg, file, line)
  end
end
