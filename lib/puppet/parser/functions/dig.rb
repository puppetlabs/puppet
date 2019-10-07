Puppet::Parser::Functions::newfunction(
  :dig,
  :type => :rvalue,
  :arity => -1,
  :doc => <<-DOC
Returns a value for a sequence of given keys/indexes into a structure, such as
an array or hash.
This function is used to "dig into" a complex data structure by
using a sequence of keys / indexes to access a value from which
the next key/index is accessed recursively.

The first encountered `undef` value or key stops the "dig" and `undef` is returned.

An error is raised if an attempt is made to "dig" into
something other than an `undef` (which immediately returns `undef`), an `Array` or a `Hash`.



**Example:** Using `dig`

```puppet
$data = {a => { b => [{x => 10, y => 20}, {x => 100, y => 200}]}}
notice $data.dig('a', 'b', 1, 'x')
```

Would notice the value 100.

This is roughly equivalent to `$data['a']['b'][1]['x']`. However, a standard
index will return an error and cause catalog compilation failure if any parent
of the final key (`'x'`) is `undef`. The `dig` function will return undef,
rather than failing catalog compilation. This allows you to check if data
exists in a structure without mandating that it always exists.

* Since 4.5.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('dig')
end
