Puppet::Parser::Functions::newfunction(
  :with,
  :type => :rvalue,
  :arity => -1,
  :doc => <<-DOC
Call a [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html)
with the given arguments and return the result. Since a lambda's scope is
[local](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html#lambda-scope)
to the lambda, you can use the `with` function to create private blocks of code within a
class using variables whose values cannot be accessed outside of the lambda.

**Example**: Using `with`

~~~ puppet
# Concatenate three strings into a single string formatted as a list.
$fruit = with("apples", "oranges", "bananas") |$x, $y, $z| {
  "${x}, ${y}, and ${z}"
}
$check_var = $x
# $fruit contains "apples, oranges, and bananas"
# $check_var is undefined, as the value of $x is local to the lambda.
~~~

- Since 4.0.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('with')
end
