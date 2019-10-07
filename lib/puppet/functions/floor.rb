# Returns the largest `Integer` less or equal to the argument.
# Takes a single numeric value as an argument.
#
# This function is backwards compatible with the same function in stdlib
# and accepts a `Numeric` value. A `String` that can be converted
# to a floating point number can also be used in this version - but this
# is deprecated.
#
# In general convert string input to `Numeric` before calling this function
# to have full control over how the conversion is done.
#
Puppet::Functions.create_function(:floor) do
  dispatch :on_numeric do
    param 'Numeric', :val
  end

  dispatch :on_string do
    param 'String', :val
  end

  def on_numeric(x)
    x.floor
  end

  def on_string(x)
    Puppet.warn_once('deprecations', 'floor_function_numeric_coerce_string',
      _("The floor() function's auto conversion of String to Float is deprecated - change to convert input before calling"))

    begin
      Float(x).floor
    rescue TypeError, ArgumentError => _e
      # TRANSLATORS: 'floor' is a name and should not be translated
      raise(ArgumentError, _('floor(): cannot convert given value to a floating point value.'))
    end
  end

end
