Puppet::Parser::Functions::newfunction(
  :map,
  :type => :rvalue,
  :arity => -3,
  :doc => <<-DOC
Applies a [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html)
to every value in a data structure and returns an array containing the results.

This function takes two mandatory arguments, in this order:

1. An array or hash the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It can
request one or two parameters.

**Example**: Using the `map` function

`$transformed_data = $data.map |$parameter| { <PUPPET CODE BLOCK> }`

or

`$transformed_data = map($data) |$parameter| { <PUPPET CODE BLOCK> }`

When the first argument (`$data` in the above example) is an array, Puppet passes each
value in turn to the lambda.

**Example**: Using the `map` function with an array and a one-parameter lambda

~~~ puppet
# For the array $data, return an array containing each value multiplied by 10
$data = [1,2,3]
$transformed_data = $data.map |$items| { $items * 10 }
# $transformed_data contains [10,20,30]
~~~

When the first argument is a hash, Puppet passes each key and value pair to the lambda
as an array in the form `[key, value]`.

**Example**: Using the `map` function with a hash and a one-parameter lambda

~~~ puppet
# For the hash $data, return an array containing the keys
$data = {'a'=>1,'b'=>2,'c'=>3}
$transformed_data = $data.map |$items| { $items[0] }
# $transformed_data contains ['a','b','c']
~~~

When the first argument is an array and the lambda has two parameters, Puppet passes the
array's indexes (enumerated from 0) in the first parameter and its values in the second
parameter.

**Example**: Using the `map` function with an array and a two-parameter lambda

~~~ puppet
# For the array $data, return an array containing the indexes
$data = [1,2,3]
$transformed_data = $data.map |$index,$value| { $index }
# $transformed_data contains [0,1,2]
~~~

When the first argument is a hash, Puppet passes its keys to the first parameter and its
values to the second parameter.

**Example**: Using the `map` function with a hash and a two-parameter lambda

~~~ puppet
# For the hash $data, return an array containing each value
$data = {'a'=>1,'b'=>2,'c'=>3}
$transformed_data = $data.map |$key,$value| { $value }
# $transformed_data contains [1,2,3]
~~~

- Since 4.0.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('map')
end
