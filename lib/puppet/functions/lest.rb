# Calls a [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
# that accepts no arguments, if the argument given to the function is `undef`.
# Returns the result of calling the lambda if the argument is `undef`. Otherwise, returns
# the given argument.
#
# The `lest` function is useful in a chain of `then` calls, or to guard against `undef`
# values. This function can be used to call the `fail` function or return a default value
# if it is passed an `undef` value.
#
# These two expressions are equivalent:
#
# ```puppet
# if $x == undef { do_things() }
# lest($x) || { do_things() }
# ```
#
# @example Using the `lest` function
#
# ```puppet
# $data = {a => [ b, c ] }
# notice $data.dig(a, b, c)
#  .then |$x| { $x * 2 }
#  .lest || { fail("no value for $data[a][b][c]" }
# ```
#
# This example invokes `lest` and fails as expected because there is no `b` key in `a`,
# leading `$data[a][b][c]` to result in `undef`.
#
# In this example, `a` does contain a `b` key, so `lest` is not invoked:
#
# ```puppet
# $data = {a => { b => { c => 10 } } }
# notice $data.dig(a, b, c)
#  .then |$x| { $x * 2 }
#  .lest || { fail("no value for $data[a][b][c]" }
# ```
#
# This example produces the notice `20`.
#
# @since 4.5.0
#
Puppet::Functions.create_function(:lest) do
  dispatch :lest do
    param 'Any', :arg
    block_param 'Callable[0,0]', :block
  end

  def lest(arg)
    if arg.nil?
      yield()
    else
      arg
    end
  end
end
