# Returns the given value if it is an instance of the given type, and raises an error otherwise.
#
# @example how to assert type
#   # assert that `$b` is a non empty `String` and assign to `$a`
#   $a = assert_type(String[1], $b)
#
# See the documentation for "The Puppet Type System" for more information about types.
#
Puppet::Functions.create_function(:assert_type) do
  dispatch :assert_type do
    param type_type(), 'type'
    param optional(object()), 'value'
  end

  # @param type [Type] the type the value must be an instance of
  # @param value [Optional[Object]] the value to assert
  #
  def assert_type(type, value)
    unless Puppet::Pops::Types::TypeCalculator.instance?(type,value)
      inferred_type = Puppet::Pops::Types::TypeCalculator.infer(value)
      raise ArgumentError, "assert_type(): Expected type #{type} does not match actual: #{inferred_type}"
    end
    value
  end
end
