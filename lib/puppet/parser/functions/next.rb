Puppet::Parser::Functions::newfunction(
  :next,
  :arity => -2,
  :doc => <<-DOC
Immediately returns the given optional value from a block (lambda), function, class body or user defined type body.
If a value is not given, an `undef` value is returned. This function does not return to the immediate caller.

The signal produced to return a value bubbles up through
the call stack until reaching a code block (lambda), function, class definition or
definition of a user defined type at which point the value given to the function will
be produced as the result of that body of code. An error is raised
if the signal to return a value reaches the end of the call stack.

**Example:** Using `next` in `each`

```puppet
$data = [1,2,3]
$data.each |$x| { if $x == 2 { next() } notice $x }
```

Would notice the values `1` and `3`

**Example:** Using `next` to produce a value

If logic consists of deeply nested conditionals it may be complicated to get out of the innermost conditional.
A call to `next` can then simplify the logic. This example however, only shows the principle.
```puppet
$data = [1,2,3]
notice $data.map |$x| { if $x == 2 { next($x*100) }; $x*10 }
```
Would notice the value `[10, 200, 30]`

* Also see functions `return` and `break`
* Since 4.8.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('next')
end
