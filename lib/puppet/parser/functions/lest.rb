Puppet::Parser::Functions::newfunction(
  :lest,
  :type => :rvalue,
  :arity => -2,
  :doc => <<-DOC
Call a [lambda](https://docs.puppet.com/puppet/latest/reference/lang_lambdas.html)
(which should accept no arguments) if the argument given to the function is `undef`.
Returns the result of calling the lambda if the argument is `undef`, otherwise the
given argument.

The `lest` function is useful in a chain of `then` calls, or in general
as a guard against `undef` values. The function can be used to call `fail`, or to
return a default value.

These two expressions are equivalent:

```puppet
if $x == undef { do_things() }
lest($x) || { do_things() }
```

**Example:** Using the `lest` function

```puppet
$data = {a => [ b, c ] }
notice $data.dig(a, b, c)
 .then |$x| { $x * 2 }
 .lest || { fail("no value for $data[a][b][c]" }
```

Would fail the operation because $data[a][b][c] results in `undef`
(there is no `b` key in `a`).

In contrast - this example:

```puppet
$data = {a => { b => { c => 10 } } }
notice $data.dig(a, b, c)
 .then |$x| { $x * 2 }
 .lest || { fail("no value for $data[a][b][c]" }
```

Would notice the value `20`

* Since 4.5.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('lest')
end
