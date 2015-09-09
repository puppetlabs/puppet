Puppet::Parser::Functions::newfunction(
  :each,
  :type => :rvalue,
  :arity => -3,
  :doc => <<-DOC
Runs a [lambda](http://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html)
repeatedly using each value in a data structure, then returns the values unchanged.

This function takes two mandatory arguments, in this order:

1. An array or hash the function will iterate over.
2. A lambda, which the function calls for each element in the first argument. It can
request one or two parameters.

**Example**: Using the `each` function

`$data.each |$parameter| { <PUPPET CODE BLOCK> }`

or

`each($data) |$parameter| { <PUPPET CODE BLOCK> }`

When the first argument (`$data` in the above example) is an array, Puppet passes each
value in turn to the lambda, then returns the original values.

**Example**: Using the `each` function with an array and a one-parameter lambda

~~~ puppet
# For the array $data, run a lambda that creates a resource for each item.
$data = ["routers", "servers", "workstations"]
$data.each |$item| {
 notify { $item:
   message => $item
 }
}
# Puppet creates one resource for each of the three items in $data. Each resource is
# named after the item's value and uses the item's value in a parameter.
~~~

When the first argument is a hash, Puppet passes each key and value pair to the lambda
as an array in the form `[key, value]` and returns the original hash.

**Example**: Using the `each` function with a hash and a one-parameter lambda

~~~ puppet
# For the hash $data, run a lambda using each item as a key-value array that creates a
# resource for each item.
$data = {"rtr" => "Router", "svr" => "Server", "wks" => "Workstation"}
$data.each |$items| {
 notify { $items[0]:
   message => $items[1]
 }
}
# Puppet creates one resource for each of the three items in $data, each named after the
# item's key and containing a parameter using the item's value.
~~~

When the first argument is an array and the lambda has two parameters, Puppet passes the
array's indexes (enumerated from 0) in the first parameter and its values in the second
parameter.

**Example**: Using the `each` function with an array and a two-parameter lambda

~~~ puppet
# For the array $data, run a lambda using each item's index and value that creates a
# resource for each item.
$data = ["routers", "servers", "workstations"]
$data.each |$index, $value| {
 notify { $value:
   message => $index
 }
}
# Puppet creates one resource for each of the three items in $data, each named after the
# item's value and containing a parameter using the item's index.
~~~

When the first argument is a hash, Puppet passes its keys to the first parameter and its
values to the second parameter.

**Example**: Using the `each` function with a hash and a two-parameter lambda

~~~ puppet
# For the hash $data, run a lambda using each item's key and value to create a resource
# for each item.
$data = {"rtr" => "Router", "svr" => "Server", "wks" => "Workstation"}
$data.each |$key, $value| {
 notify { $key:
   message => $value
 }
}
# Puppet creates one resource for each of the three items in $data, each named after the
# item's key and containing a parameter using the item's value.
~~~

For an example that demonstrates how to create multiple `file` resources using `each`,
see the Puppet
[iteration](https://docs.puppetlabs.com/puppet/latest/reference/lang_iteration.html)
documentation.

- Since 4.0.0
DOC
) do |args|
  function_fail(["each() is only available when parser/evaluator future is in effect"])
end
