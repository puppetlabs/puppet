# Returns the smallest `Integer` greater or equal to the argument.
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
Puppet::Functions.create_function(:ceiling) do
  dispatch :on_numeric do
    param 'Numeric', :val
  end

  dispatch :on_string do
    param 'String', :val
  end

  def on_numeric(x)
    x.ceil
  end

  def on_string(x)
    Puppet.warn_once('deprecations', 'ceiling_function_numeric_coerce_string',
      _("The ceiling() function's auto conversion of String to Float is deprecated - change to convert input before calling"))

    begin
      Float(x).ceil
    rescue TypeError, ArgumentError => _e
      # TRANSLATORS: 'ceiling' is a name and should not be translated
      raise(ArgumentError, _('ceiling(): cannot convert given value to a floating point value.'))
    end
  end

end
