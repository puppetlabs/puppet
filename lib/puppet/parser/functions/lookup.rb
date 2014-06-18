Puppet::Parser::Functions.newfunction(:lookup, :type => :rvalue, :arity => -2, :doc => <<-'ENDHEREDOC') do |args|
Looks up data defined using Puppet Bindings and Hiera.
The function is callable with one to three arguments and optionally with a code block to further process the result.

The lookup function can be called in one of these ways:

    lookup(name)
    lookup(name, type)
    lookup(name, type, default)
    lookup(options_hash)
    lookup(name, options_hash)

The function may optionally be called with a code block / lambda with the following signatures:

    lookup(...) |$result| { ... }
    lookup(...) |$name, $result| { ... }
    lookup(...) |$name, $result, $default| { ... }

The longer signatures are useful when the block needs to raise an error (it can report the name), or
if it needs to know if the given default value was selected.

The code block receives the following three arguments:

* The `$name` is the last name that was looked up (*the* name if only one name was looked up)
* The `$result` is the looked up value (or the default value if not found).
* The `$default` is the given default value (`undef` if not given).

The block, if present, is called with the result from the lookup. The value produced by the block is also what is
produced by the `lookup` function.
When a block is used, it is the users responsibility to call `error` if the result does not meet additional
criteria, or if an undef value is not acceptable. If a value is not found, and a default has been
specified, the default value is given to the block.

The content of the options hash is:

* `name` - The name or array of names to lookup (first found is returned)
* `type` - The type to assert (a Type or a type specification in string form)
* `default` - The default value if there was no value found (must comply with the data type)
* `accept_undef` - (default `false`) An `undef` result is accepted if this options is set to `true`.
* `override` - a hash with map from names to values that are used instead of the underlying bindings. If the name
  is found here it wins. Defaults to an empty hash.
* `extra` - a hash with map from names to values that are used as a last resort to obtain a value. Defaults to an
  empty hash.

When the call is on the form `lookup(name, options_hash)`, or `lookup(name, type, options_hash)`, the given name
argument wins over the `options_hash['name']`.

The search order is `override` (if given), then `binder`, then `hiera` and finally `extra` (if given). The first to produce
a value other than undef for a given name wins.

The type specification is one of:

  * A type in the Puppet Type System, e.g.:
    * `Integer`, an integral value with optional range e.g.:
      * `Integer[0, default]` - 0 or positive
      * `Integer[default, -1]` - negative, 
      * `Integer[1,100]` - value between 1 and 100 inclusive
    * `String`- any string
    * `Float` - floating point number (same signature as for Integer for `Integer` ranges)
    * `Boolean` - true of false (strict)
    * `Array` - an array (of Data by default), or parameterized as `Array[<element_type>]`, where
      `<element_type>` is the expected type of elements
    * `Hash`,  - a hash (of default `Literal` keys and `Data` values), or parameterized as
      `Hash[<value_type>]`, `Hash[<key_type>, <value_type>]`, where `<key_type>`, and
      `<value_type>` are the types of the keys and values respectively
      (key is `Literal` by default).
    * `Data` - abstract type representing any `Literal`, `Array[Data]`, or `Hash[Literal, Data]`
    * `Pattern[<p1>, <p2>, ..., <pn>]` - an enumeration of valid patterns (one or more) where
       a pattern is a regular expression string or regular expression,
       e.g. `Pattern['.com$', '.net$']`, `Pattern[/[a-z]+[0-9]+/]` 
    * `Enum[<s1>, <s2>, ..., <sn>]`, - an enumeration of exact string values (one or more)
       e.g. `Enum[blue, red, green]`.
    * `Variant[<t1>, <t2>,...<tn>]` - matches one of the listed types (at least one must be given)
      e.g. `Variant[Integer[8000,8999], Integer[20000, 99999]]` to accept a value in either range
    * `Regexp`- a regular expression (i.e. the result is a regular expression, not a string
       matching a regular expression).
  * A string containing a type description - one of the types as shown above but in string form.

If the function is called without specifying a default value, and nothing is bound to the given name 
an error is raised unless the option `accept_undef` is true. If a block is given it must produce an acceptable
value (or call `error`). If the block does not produce an acceptable value an error is
raised.

Examples:

When called with one argument; **the name**, it
returns the bound value with the given name after having  asserted it has the default datatype `Data`:

    lookup('the_name')

When called with two arguments; **the name**, and **the expected type**, it
returns the bound value with the given name after having asserted it has the given data
type ('String' in the example):

    lookup('the_name', 'String') # 3.x
    lookup('the_name', String)   # parser future

When called with three arguments, **the name**, the **expected type**, and a **default**, it
returns the bound value with the given name, or the default after having asserted the value
has the given data type (`String` in the example above):

    lookup('the_name', 'String', 'Fred') # 3x
    lookup('the_name', String, 'Fred')   # parser future

Using a lambda to process the looked up result - asserting that it starts with an upper case letter:

    # only with parser future
    lookup('the_size', Integer[1,100]) |$result| {
      if $large_value_allowed and $result > 10
        { error 'Values larger than 10 are not allowed'}
      $result
    }

Including the name in the error

    # only with parser future
    lookup('the_size', Integer[1,100]) |$name, $result| {
      if $large_value_allowed and $result > 10
        { error 'The bound value for '${name}' can not be larger than 10 in this configuration'}
      $result
    }

When using a block, the value it produces is also asserted against the given type, and it may not be
`undef` unless the option `'accept_undef'` is `true`.

All options work as the corresponding (direct) argument. The `first_found` option and
`accept_undef` are however only available as options.

Using first_found semantics option to return the first name that has a bound value:

    lookup(['apache::port', 'nginx::port'], 'Integer', 80)

If you want to make lookup return undef when no value was found instead of raising an error:

     $are_you_there = lookup('peekaboo', { accept_undef => true} )
     $are_you_there = lookup('peekaboo', { accept_undef => true}) |$result| { $result }

ENDHEREDOC

  unless Puppet[:binder] || Puppet[:parser] == 'future'
    raise Puppet::ParseError, "The lookup function is only available with settings --binder true, or --parser future"
  end
  Puppet::Pops::Binder::Lookup.lookup(self, args)
end
