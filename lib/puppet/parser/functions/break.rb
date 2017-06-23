Puppet::Parser::Functions::newfunction(
  :break,
  :arity => 0,
  :doc => <<-DOC
Breaks the innermost iteration as if it encountered an end of input.
This function does not return to the caller.

The signal produced to stop the iteration bubbles up through
the call stack until either terminating the innermost iteration or
raising an error if the end of the call stack is reached.

The break() function does not accept an argument.

**Example:** Using `break`

```puppet
$data = [1,2,3]
notice $data.map |$x| { if $x == 3 { break() } $x*10 }
```

Would notice the value `[10, 20]`

**Example:** Using a nested `break`

```puppet
function break_if_even($x) {
  if $x % 2 == 0 { break() }
}
$data = [1,2,3]
notice $data.map |$x| { break_if_even($x); $x*10 }
```
Would notice the value `[10]`

* Also see functions `next` and `return`
* Since 4.8.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('break')
end
