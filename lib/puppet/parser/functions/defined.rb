Puppet::Parser::Functions::newfunction(
  :defined,
  :type => :rvalue,
  :arity => -2,
  :doc => <<DOC
Determines whether a given class or resource type is defined and returns a Boolean
value. You can also use `defined` to determine whether a specific resource is defined,
or whether a variable has a value (including `undef`, as opposed to the variable never
being declared or assigned).

This function takes at least one string argument, which can be a class name, type name,
resource reference, or variable reference of the form `'$name'`.

The `defined` function checks both native and defined types, including types
provided by modules. Types and classes are matched by their names. The function matches 
resource declarations by using resource references.

**Examples**: Different types of `defined` function matches

~~~ puppet
# Matching resource types
defined("file")
defined("customtype")

# Matching defines and classes
defined("foo")
defined("foo::bar")

# Matching variables
defined('$name')

# Matching declared resources
defined(File['/tmp/file'])
~~~

Puppet depends on the configuration's evaluation order when checking whether a resource
is declared.

**Example**: Importance of evaluation order when using `defined`

~~~ puppet
# Assign values to $is_defined_before and $is_defined_after using identical `defined`
# functions.

$is_defined_before = defined(File['/tmp/file'])

file { "/tmp/file":
  ensure => present,
}

$is_defined_after = defined(File['/tmp/file'])

# $is_defined_before returns false, but $is_defined_after returns true.
~~~

This order requirement only refers to evaluation order. The order of resources in the
configuration graph (e.g. with `before` or `require`) does not affect the `defined`
function's behavior.

> **Warning:** Avoid relying on the result of the `defined` function in modules, as you
> might not be able to guarantee the evaluation order well enough to produce consistent
> results. This can cause other code that relies on the function's result to behave
> inconsistently or fail.

If you pass more than one argument to `defined`, the function returns `true` if _any_
of the arguments are defined. You can also match resources by type, allowing you to
match conditions of different levels of specificity, such as whether a specific resource
is of a specific data type.

**Example**: Matching multiple resources and resources by different types with `defined`

~~~ puppet
file { "/tmp/file1":
  ensure => file,
}

$tmp_file = file { "/tmp/file2":
  ensure => file,
}

# Each of these statements return `true` ...
defined(File['/tmp/file1'])
defined(File['/tmp/file1'],File['/tmp/file2'])
defined(File['/tmp/file1'],File['/tmp/file2'],File['/tmp/file3'])
# ... but this returns `false`.
defined(File['/tmp/file3'])

# Each of these statements returns `true` ...
defined(Type[Resource['file','/tmp/file2']])
defined(Resource['file','/tmp/file2'])
defined(File['/tmp/file2'])
defined('$tmp_file')
# ... but each of these returns `false`.
defined(Type[Resource['exec','/tmp/file2']])
defined(Resource['exec','/tmp/file2'])
defined(File['/tmp/file3'])
defined('$tmp_file2')
~~~

- Since 2.7.0
- Since 3.6.0 variable reference and future parser types
- Since 3.8.1 type specific requests with future parser
- Since 4.0.0 includes all future parser features
DOC
) do |vals|
  function_fail(["defined() is a 4.x function - an illegal call was made to this function using old API"])
end
