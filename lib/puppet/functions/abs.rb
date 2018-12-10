# Returns the absolute value of a Numeric value, for example -34.56 becomes
# 34.56. Takes a single `Integer` or `Float` value as an argument.
#
# *Deprecated behavior*
#
# For backwards compatibility reasons this function also works when given a
# number in `String` format such that it first attempts to covert it to either a `Float` or
# an `Integer` and then taking the absolute value of the result. Only strings representing
# a number in decimal format is supported - an error is raised if
# value is not decimal (using base 10). Leading 0 chars in the string
# are ignored. A floating point value in string form can use some forms of
# scientific notation but not all.
#
# Callers should convert strings to `Numeric` before calling
# this function to have full control over the conversion.
#
# @example Converting to Numeric before calling
# ```puppet
# abs(Numeric($str_val))
# ```
# 
# It is worth noting that `Numeric` can convert to absolute value
# directly as in the following examples:
#
# @example Absolute value and String to Numeric
# ```puppet
# Numeric($strval, true)     # Converts to absolute Integer or Float
# Integer($strval, 10, true) # Converts to absolute Integer using base 10 (decimal)
# Integer($strval, 16, true) # Converts to absolute Integer using base 16 (hex)
# Float($strval, true)       # Converts to absolute Float
# ```
#
Puppet::Functions.create_function(:abs) do
  dispatch :on_numeric do
    param 'Numeric', :val
  end

  dispatch :on_string do
    param 'String', :val
  end

  def on_numeric(x)
    x.abs
  end

  def on_string(x)
    Puppet.warn_once('deprecations', 'abs_function_numeric_coerce_string',
      _("The abs() function's auto conversion of String to Numeric is deprecated - change to convert input before calling"))

    # These patterns for conversion are backwards compatible with the stdlib
    # version of this function.
    #
    if x =~ %r{^-?(?:\d+)(?:\.\d+){1}$}
      x.to_f.abs
    elsif x =~ %r{^-?\d+$}
      x.to_i.abs
    else
      raise(ArgumentError, 'abs(): Requires float or integer to work with - was given non decimal string')
    end
  end
end
