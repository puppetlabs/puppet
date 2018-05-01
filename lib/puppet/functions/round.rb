# Returns an `Integer` value rounded to the nearest value.
# Takes a single `Numeric` value as an argument.
#
# @example 'rounding a value'
#
# ```puppet
# notice(round(2.9)) # would notice 3
# notice(round(2.1)) # would notice 2
# notice(round(-2.9)) # would notice -3
# ```
#
Puppet::Functions.create_function(:round) do
  dispatch :on_numeric do
    param 'Numeric', :val
  end

  def on_numeric(x)
    if x > 0
      Integer(x + 0.5)
    else
      Integer(x - 0.5)
    end
  end
end
