# Returns the given value if it is of the given
# [data type](https://docs.puppetlabs.com/puppet/latest/reference/lang_data.html), or
# otherwise either raises an error or executes an optional two-parameter
# [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html).
#
# The function takes two mandatory arguments, in this order:
#
# 1. The expected data type.
# 2. A value to compare against the expected data type.
#
# @example Using `assert_type`
#
# ~~~ puppet
# $raw_username = 'Amy Berry'
#
# # Assert that $raw_username is a non-empty string and assign it to $valid_username.
# $valid_username = assert_type(String[1], $raw_username)
#
# # $valid_username contains "Amy Berry".
# # If $raw_username was an empty string or a different data type, the Puppet run would
# # fail with an "Expected type does not match actual" error.
# ~~~
#
# You can use an optional lambda to provide enhanced feedback. The lambda takes two
# mandatory parameters, in this order:
#
# 1. The expected data type as described in the function's first argument.
# 2. The actual data type of the value.
#
# @example Using `assert_type` with a warning and default value
#
# ~~~ puppet
# $raw_username = 'Amy Berry'
#
# # Assert that $raw_username is a non-empty string and assign it to $valid_username.
# # If it isn't, output a warning describing the problem and use a default value.
# $valid_username = assert_type(String[1], $raw_username) |$expected, $actual| {
#   warning( "The username should be \'${expected}\', not \'${actual}\'. Using 'anonymous'." )
#   'anonymous'
# }
#
# # $valid_username contains "Amy Berry".
# # If $raw_username was an empty string, the Puppet run would set $valid_username to
# # "anonymous" and output a warning: "The username should be 'String[1, default]', not
# # 'String[0, 0]'. Using 'anonymous'."
# ~~~
#
# For more information about data types, see the
# [documentation](https://docs.puppetlabs.com/puppet/latest/reference/lang_data.html).
#
# @since 4.0.0
#
Puppet::Functions.create_function(:assert_type, Puppet::Functions::InternalFunction) do
  dispatch :assert_type do
    param 'Type', :type
    param 'Any', :value
    optional_block_param 'Callable[Type, Type]', :block
  end

  dispatch :assert_type_s do
    scope_param
    param 'String', :type_string
    param 'Any', :value
    optional_block_param 'Callable[Type, Type]', :block
  end

  # @param type [Type] the type the value must be an instance of
  # @param value [Object] the value to assert
  #
  def assert_type(type, value)
    unless Puppet::Pops::Types::TypeCalculator.instance?(type,value)
      inferred_type = Puppet::Pops::Types::TypeCalculator.infer_set(value)
      if block_given?
        # Give the inferred type to allow richer comparison in the given block (if generalized
        # information is lost).
        #
        value = yield(type, inferred_type)
      else
        raise Puppet::Pops::Types::TypeAssertionError.new(
          Puppet::Pops::Types::TypeMismatchDescriber.singleton.describe_mismatch('assert_type():', type, inferred_type),
          type, inferred_type)
      end
    end
    value
  end

  # @param scope [Puppet::Parser::Scope] scope used when obtaining loader for defined types
  # @param type_string [String] the type the value must be an instance of given in String form
  # @param value [Object] the value to assert
  #
  def assert_type_s(scope, type_string, value, &proc)
    t = Puppet::Pops::Types::TypeParser.new.parse(type_string, scope)
    block_given? ? assert_type(t, value, &proc) : assert_type(t, value)
  end
end
