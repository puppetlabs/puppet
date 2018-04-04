Puppet::Parser::Functions::newfunction(
  :return,
  :arity => -2,
  :doc => <<-DOC
Immediately returns the given optional value from a function, class body or user defined type body.
If a value is not given, an `undef` value is returned. This function does not return to the immediate caller.
If this function is called from within a lambda, the return action is from the scope of the
function containing the lambda (top scope), not the function accepting the lambda (local scope).

The signal produced to return a value bubbles up through
the call stack until reaching a function, class definition or
definition of a user defined type at which point the value given to the function will
be produced as the result of that body of code. An error is raised
if the signal to return a value reaches the end of the call stack.

**Example:** Using `return`

```puppet
function example($x) {
  # handle trivial cases first for better readability of
  # what follows
  if $x == undef or $x == [] or $x == '' {
    return false
  }
  # complex logic to determine if value is true
  true 
}
notice example([]) # would notice false
notice example(42) # would notice true
```

**Example:** Using `return` in a class

```puppet
class example($x) {
  # handle trivial cases first for better readability of
  # what follows
  if $x == undef or $x == [] or $x == '' {
    # Do some default configuration of this class
    notice 'foo'
    return()
  }
  # complex logic configuring the class if something more interesting
  # was given in $x
  notice 'bar'
}
```

When used like this:

```puppet
class { example: x => [] }
```

The code would notice `'foo'`, but not `'bar'`.

When used like this:

```puppet
class { example: x => [some_value] }
```

The code would notice `'bar'` but not `'foo'`

Note that the returned value is ignored if used in a class or user defined type.

**Example:** Using `return` in a lambda

```puppet
# Concatenate three strings into a single string formatted as a list.
function getFruit() {
  with("apples", "oranges", "bananas") |$x, $y, $z| {
    return("${x}, ${y}, and ${z}")
  }
  notice "not reached"
}
$fruit = getFruit()
notice $fruit

# The output contains "apples, oranges, and bananas".
# "not reached" is not output because the function returns its value within the
# calling function's scope, which stops processing the calling function before
# the `notice "not reached"` statement.
# Using `return()` outside of a calling function results in an error.
```

* Also see functions `return` and `break`
* Since 4.8.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('return')
end
