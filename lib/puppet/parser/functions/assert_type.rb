Puppet::Parser::Functions::newfunction(
  :assert_type,
  :type => :rvalue,
  :arity => -3,
  :doc => <<DOC
Returns the given value if it is of the given
[data type](https://docs.puppetlabs.com/puppet/latest/reference/lang_data.html), or
otherwise either raises an error or executes an optional two-parameter
[lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html).

The function takes two mandatory arguments, in this order:

1. The expected data type.
2. A value to compare against the expected data type.

**Example**: Using `assert_type`

~~~ puppet
$raw_username = 'Amy Berry'

# Assert that $raw_username is a non-empty string and assign it to $valid_username.
$valid_username = assert_type(String[1], $raw_username)

# $valid_username contains "Amy Berry".
# If $raw_username was an empty string or a different data type, the Puppet run would
# fail with an "Expected type does not match actual" error.
~~~

You can use an optional lambda to provide enhanced feedback. The lambda takes two
mandatory parameters, in this order:

1. The expected data type as described in the function's first argument.
2. The actual data type of the value.

**Example**: Using `assert_type` with a warning and default value

~~~ puppet
$raw_username = 'Amy Berry'

# Assert that $raw_username is a non-empty string and assign it to $valid_username.
# If it isn't, output a warning describing the problem and use a default value.
$valid_username = assert_type(String[1], $raw_username) |$expected, $actual| {
  warning( "The username should be \'${expected}\', not \'${actual}\'. Using 'anonymous'." )
  'anonymous'
}

# $valid_username contains "Amy Berry".
# If $raw_username was an empty string, the Puppet run would set $valid_username to
# "anonymous" and output a warning: "The username should be 'String[1, default]', not
# 'String[0, 0]'. Using 'anonymous'."
~~~

For more information about data types, see the
[documentation](https://docs.puppetlabs.com/puppet/latest/reference/lang_data.html).

- Since 4.0.0
DOC
) do |args|
  function_fail(["assert_type() is only available when parser/evaluator future is in effect"])
end
