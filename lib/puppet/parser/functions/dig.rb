Puppet::Parser::Functions::newfunction(
  :dig,
  :type => :rvalue,
  :arity => -1,
  :doc => <<-DOC
Returns a value for a sequence of given keys/indexes into a structure.
This function is used to "dig into" a complex data structure by
using a sequence of keys / indexes to access a value from which
the next key/index is accessed recursively.

The first encountered `undef` value or key stops the "dig" and `undef` is returned.

An error is raised if an attempt is made to "dig" into
something other than an `undef` (which immediately returns `undef`), an `Array` or a `Hash`.

**Example:** Using `dig`

```puppet
$data = {a => { b => [{x => 10, y => 20}, {x => 100, y => 200}]}}
notice $data.dig(a, b, 1, x)
```

Would notice the value 100.

* Since 4.5.0
DOC
) do |args|
  function_fail(["dig() is only available when parser/evaluator future is in effect"])
end
