Puppet::Parser::Functions.newfunction(:lookup, :type => :rvalue, :arity => -2, :doc => <<-'ENDHEREDOC') do |args|
Looks up data defined using Data Binding, and Data Providers using different strategies. The lookup searches in
Data Bindings first (if configured; typically Hiera), then in the environments data provider (if any), and last in
the module's data provider (if any) of the module the call to lookup originates from. Thus, the global Data Binding
has higher priority than data provided in the environment, which has higher priority than data provided in a module,

The lookup function can be called in one of these ways:

    lookup(name)
    lookup(name, value_type)
    lookup(name, value_type, merge)
    lookup(name, value_type, merge, default_value)
    lookup(options_hash)
    lookup(name, options_hash)

The function may optionally be called with a code block / lambda with the following signature:

    lookup(...) |$name| { ... }

The block, if present, is mutually exclusive to the `default_value` and will be called with the `name` used in the
lookup when no value is found. The value produced by the block then becomes the value produced by the lookup.

The meaning of the parameters or content of the options hash is:

* `name` - The name or array of names to lookup (first found is returned)
* `value_type` - The type to assert. Defaults to 'Data' See 'Type Specification' below.
* `default_value` - The default value if there was no value found (must comply with the data type)
* `override` - a hash with map from names to values that are used instead of the underlying bindings. If the name
  is found here it wins. Defaults to an empty hash.
* `default_values_hash` - a hash with map from names to values that are used as a last resort to obtain a value.
  Defaults to an empty hash.
* `merge` - A string of type Enum[unique, hash, merge] or a hash with the key 'strategy' set to that string. See
  'Merge Strategies' below.

It is not permitted to pass the `name` as both a parameter and in the options hash.

The search will proceed as follows:
1. For each name given in the `name` array (or once, if it's just one name):
  - If a matching key is found in the `override` hash, it's value is immediately type checked and returned
  - Search and optionally merge Data Binding, environment data providers, and module data providers
  - Type check and return the value if a matching key is found
2. For each name given in the `name` array (or once, if it's just one name):
  - Type check and return the value if a matching key is found in the `default_values_hash`
3. Type check and return either the given `default_value` or the result of calling the code block if either exist
4. Raise an error indicating that no matching value was found

*Merge Strategies*

The default behavior of the lookup is to return the first value that is found for the given `name`. The optional
`merge` parameter will change this so that a lookup makes an attempt to find values in all three sources (the Data
Binder, the environment, and the module scope) and then merge these values according to the given strategy. This
does not apply to values found in the 'override' hash. Such values are returned immediately without merging.
Note that `merge` is passed on to allow the underlying provider to return a merged result

The valid strategies are:
- 'hash' Performs a simple hash-merge by overwriting keys of lower lookup priority. Merged values must be of Hash type
- 'unique' Appends everything to an array containing no nested arrays and where all duplicates have been removed. Can
   append values of Scalar or Array[Scalar] type
- 'deep' Performs a deep merge on values of Array and Hash type. See documentation for the DeepMerge gem's deep_merge
   operation for details and options.

The 'deep' strategy can use additional options to control its behavior. Options can be passed as top level
keys in the `merge` parameter when it is a given as a hash. Recognized options are:
- 'knockout_prefix' Set to string value to signify prefix which deletes elements from existing element. Defaults is _undef_
- 'sort_merged_arrays' Set to _true_ to sort all arrays that are merged together. Default is _false_
- 'unpack_arrays' Set to string value used as a deliminator to join all array values and then split them again. Default is _undef_
- 'merge_hash_arrays' Set to _true_ to merge hashes within arrays. Default is _false_

*Type Specification*

The type specification is a type in the Puppet Type System, e.g.:
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
  * `Data` - abstract type representing any `Literal` (including _undef_), `Array[Data]`, or `Hash[Literal, Data]`
  * `Pattern[<p1>, <p2>, ..., <pn>]` - an enumeration of valid patterns (one or more) where
     a pattern is a regular expression string or regular expression,
     e.g. `Pattern['.com$', '.net$']`, `Pattern[/[a-z]+[0-9]+/]`
  * `Enum[<s1>, <s2>, ..., <sn>]`, - an enumeration of exact string values (one or more)
     e.g. `Enum[blue, red, green]`.
  * `Variant[<t1>, <t2>,...<tn>]` - matches one of the listed types (at least one must be given)
    e.g. `Variant[Integer[8000,8999], Integer[20000, 99999]]` to accept a value in either range
  * `Regexp`- a regular expression (i.e. the result is a regular expression, not a string
     matching a regular expression).

For more options and details about types, see the Puppet Language Reference

*Handling of undef*

When no match is found for the given `name` when searching all sources, (including the `override`and
`default_values_hash`), then the value used is either the `default_value` or the value produced by the given block.
If neither is provided, then the lookup will always raise an error. Note that this only applies when there's no
match for the given `name`. It does not happen when a value is found and that value happens to be _undef_.

*Validation of returned value*

The produced value is subject to type validation using the `value_type` (if given) and an error is raised unless
the resulting value is of correct type.

*Examples*

When called with one argument; **the name**, it
returns the bound value with the given name after having  asserted it has the default datatype `Data`:

    lookup('the_name')

When called with two arguments; **the name**, and **the expected type**, it
returns the bound value with the given name after having asserted it has the given data
type ('String' in the example):

    lookup('the_name', String)

When called with four arguments, **the name**, the **expected type**, the **merge** strategy, and a
**default value**, it returns the bound value with the given name, or the default after having asserted the value
has the given data type:

    lookup('the_name', String, undef, 'Fred')
    lookup('the_name', Array[String], 'unique', [Fred])

Using a lambda to provide a default value by calling a function:

    lookup('the_size', Integer[1,100]) |$name| {
      obtain_size_default()
    }

There are two ways to make lookup return undef when no matching key was found instead of raising an error.
Either call it with four arguments (the `merge` argument must be present even when using the default strategy
to ensure that the four argument variant is used):

     $are_you_there = lookup('peekaboo', Optional[String], undef, undef)

or call it using an options hash:

     $are_you_there = lookup('peekaboo', { 'default_value' => undef })
     $are_you_there = lookup({ 'name' => 'peekaboo', 'default_value' => undef })

or with a block that produces an undef value:

     $are_you_there = lookup('peekaboo', Optional[String]) |$name| { undef }

- Since 4.0.0
ENDHEREDOC
  function_fail(["lookup() has been converted to 4x API"])
end
