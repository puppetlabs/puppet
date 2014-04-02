# Returns the give value if it is an instance of the given type, and raises an error otherwise.
#
Puppet::Functions.create_function(:assert_type) do
  dispatch :assert_type do
    param type_type(), 'type'
    param optional(object()), 'value'
  end

  def assert_type(type, value)
    unless Puppet::Pops::Types::TypeCalculator.instance?(type,value)
      inferred_type = Puppet::Pops::Types::TypeCalculator.infer(value)
      raise ArgumentError, "assert_type(): Expected type #{type} does not match actual: #{inferred_type}"
    end
    value
  end
end
