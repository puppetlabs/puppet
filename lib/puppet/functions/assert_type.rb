# Returns the given value if it is an instance of the given type, and raises an error otherwise.
# Optionally, if a block is given (accepting two parameters), it will be called instead of raising
# an error. This to enable giving the user richer feedback, or to supply a default value.
#
# @example how to assert type
#   # assert that `$b` is a non empty `String` and assign to `$a`
#   $a = assert_type(String[1], $b)
#
# @example using custom error message
#   $a = assert_type(String[1], $b) |$expected, $actual| { fail("The name cannot be empty") }
#
# @example using a warning and a default
#   $a = assert_type(String[1], $b) |$expected, $actual| { warning("Name is empty, using default") 'anonymous' }
#
# See the documentation for "The Puppet Type System" for more information about types.
#
Puppet::Functions.create_function(:assert_type) do
  dispatch :assert_type do
    param 'Type', 'type'
    param 'Any', 'value'
    optional_block_param 'Callable[Type, Type]', 'block'
  end

  dispatch :assert_type_s do
    param 'String', 'type_string'
    param 'Any', 'value'
    optional_block_param 'Callable[Type, Type]', 'block'
  end

  # @param type [Type] the type the value must be an instance of
  # @param value [Object] the value to assert
  #
  def assert_type(type, value, block=nil)
    unless Puppet::Pops::Types::TypeCalculator.instance?(type,value)
      inferred_type = Puppet::Pops::Types::TypeCalculator.infer(value)
      if block
        # Give the inferred type to allow richer comparisson in the given block (if generalized
        # information is lost).
        #
        value = block.call(nil, type, inferred_type)
      else
        # Do not give all the details - i.e. format as Integer, instead of Integer[n, n] for exact value, which
        # is just confusing. (OTOH: may need to revisit, or provide a better "type diff" output.
        #
        actual = Puppet::Pops::Types::TypeCalculator.generalize!(inferred_type)
        raise Puppet::ParseError, "assert_type(): Expected type #{type} does not match actual: #{actual}"
      end
    end
    value
  end

  # @param type_string [String] the type the value must be an instance of given in String form
  # @param value [Object] the value to assert
  #
  def assert_type_s(type_string, value)
    t = Puppet::Pops::Types::TypeParser.new.parse(type_string)
    assert_type(t, value)
  end
end
