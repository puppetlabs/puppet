# Call a [lambda](https://docs.puppet.com/puppet/latest/reference/lang_lambdas.html)
# with the given arguments and return the result. Since a lambda's scope is
# [local](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html#lambda-scope)
# to the lambda, you can use the `with` function to create private blocks of code within a
# class using variables whose values cannot be accessed outside of the lambda.
#
# @example Using `with`
#
# ~~~ puppet
# # Concatenate three strings into a single string formatted as a list.
# $fruit = with("apples", "oranges", "bananas") |$x, $y, $z| { 
#   "${x}, ${y}, and ${z}" 
# }
# $check_var = $x
# # $fruit contains "apples, oranges, and bananas"
# # $check_var is undefined, as the value of $x is local to the lambda.
# ~~~
#
# @since 4.0.0
#
Puppet::Functions.create_function(:with) do
  dispatch :with do
    repeated_param 'Any', :arg
    block_param
  end

  def with(*args)
    yield(*args)
  end
end
