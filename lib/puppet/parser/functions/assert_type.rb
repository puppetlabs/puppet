Puppet::Parser::Functions::newfunction(
  :assert_type,
  :type => :rvalue,
  :arity => -3,
  :doc => "Returns the given value if it is an instance of the given type, and raises an error otherwise.
Optionally, if a block is given (accepting two parameters), it will be called instead of raising
an error. This to enable giving the user richer feedback, or to supply a default value.

Example: assert that `$b` is a non empty `String` and assign to `$a`:

  $a = assert_type(String[1], $b)

Example using custom error message:

  $a = assert_type(String[1], $b) |$expected, $actual| {
    fail('The name cannot be empty')
  }

Example, using a warning and a default:

  $a = assert_type(String[1], $b) |$expected, $actual| {
    warning('Name is empty, using default')
    'anonymous'
  }

See the documentation for 'The Puppet Type System' for more information about types.
- since Puppet 3.7
- requires future parser/evaluator
") do |args|
  function_fail(["assert_type() is only available when parser/evaluator future is in effect"])
end
