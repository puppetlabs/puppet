Puppet::Parser::Functions::newfunction(
  :reduce,
  :type => :rvalue,
  :arity => -3,
  :doc => <<-DOC
Applies a [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html)
to every value in a data structure from the first argument, carrying over the returned
value of each iteration, and returns the result of the lambda's final iteration. This
lets you create a new value or data structure by combining values from the first
argument's data structure.

This function takes two mandatory arguments, in this order:

1. An array or hash the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It takes
two mandatory parameters:
    1. A memo value that is overwritten after each iteration with the iteration's result.
    2. A second value that is overwritten after each iteration with the next value in the
    function's first argument.

**Example**: Using the `reduce` function

`$data.reduce |$memo, $value| { ... }`

or

`reduce($data) |$memo, $value| { ... }`

You can also pass an optional "start memo" value as an argument, such as `start` below:

`$data.reduce(start) |$memo, $value| { ... }`

or

`reduce($data, start) |$memo, $value| { ... }`

When the first argument (`$data` in the above example) is an array, Puppet passes each
of the data structure's values in turn to the lambda's parameters. When the first
argument is a hash, Puppet converts each of the hash's values to an array in the form
`[key, value]`.

If you pass a start memo value, Puppet executes the lambda with the provided memo value
and the data structure's first value. Otherwise, Puppet passes the structure's first two
values to the lambda.

Puppet calls the lambda for each of the data structure's remaining values. For each
call, it passes the result of the previous call as the first parameter ($memo in the
above examples) and the next value from the data structure as the second parameter
($value).

If the structure has one value, Puppet returns the value and does not call the lambda.

**Example**: Using the `reduce` function

~~~ puppet
# Reduce the array $data, returning the sum of all values in the array.
$data = [1, 2, 3]
$sum = $data.reduce |$memo, $value| { $memo + $value }
# $sum contains 6

# Reduce the array $data, returning the sum of a start memo value and all values in the
# array.
$data = [1, 2, 3]
$sum = $data.reduce(4) |$memo, $value| { $memo + $value }
# $sum contains 10

# Reduce the hash $data, returning the sum of all values and concatenated string of all
# keys.
$data = {a => 1, b => 2, c => 3}
$combine = $data.reduce |$memo, $value| {
  $string = "${memo[0]}${value[0]}"
  $number = $memo[1] + $value[1]
  [$string, $number]
}
# $combine contains [abc, 6]
~~~

**Example**: Using the `reduce` function with a start memo and two-parameter lambda

~~~ puppet
# Reduce the array $data, returning the sum of all values in the array and starting
# with $memo set to an arbitrary value instead of $data's first value.
$data = [1, 2, 3]
$sum = $data.reduce(4) |$memo, $value| { $memo + $value }
# At the start of the lambda's first iteration, $memo contains 4 and $value contains 1.
# After all iterations, $sum contains 10.

# Reduce the hash $data, returning the sum of all values and concatenated string of
# all keys, and starting with $memo set to an arbitrary array instead of $data's first
# key-value pair.
$data = {a => 1, b => 2, c => 3}
$combine = $data.reduce( [d, 4] ) |$memo, $value| {
  $string = "${memo[0]}${value[0]}"
  $number = $memo[1] + $value[1]
  [$string, $number]
}
# At the start of the lambda's first iteration, $memo contains [d, 4] and $value
# contains [a, 1].
# $combine contains [dabc, 10]
~~~

**Example**: Using the `reduce` function to reduce a hash of hashes

~~~ puppet
# Reduce a hash of hashes $data, merging defaults into the inner hashes.
$data = {
  'connection1' => {
    'username' => 'user1',
    'password' => 'pass1',
  },
  'connection_name2' => {
    'username' => 'user2',
    'password' => 'pass2',
  },
}

$defaults = {
  'maxActive' => '20',
  'maxWait'   => '10000',
  'username'  => 'defaultuser',
  'password'  => 'defaultpass',
}

$merged = $data.reduce( {} ) |$memo, $x| {
  $memo + { $x[0] => $defaults + $data[$x[0]] }
}
# At the start of the lambda's first iteration, $memo is set to {}, and $x is set to
# the first [key, value] tuple. The key in $data is, therefore, given by $x[0]. In
# subsequent rounds, $memo retains the value returned by the expression, i.e.
# $memo + { $x[0] => $defaults + $data[$x[0]] }.
~~~

- Since 4.0.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('reduce')
end
