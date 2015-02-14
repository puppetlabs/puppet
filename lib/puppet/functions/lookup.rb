# Looks up data defined using Hiera and Data Providers
# The function is callable with one to four arguments and optionally with a code block to provide default value.
#
# The lookup function can be called in one of these ways:
#
#     lookup(name)
#     lookup(name, value_type)
#     lookup(name, value_type, default_value)
#     lookup(name, value_type, default_value, merge)
#     lookup(options_hash)
#     lookup(name, options_hash)
#
# The function may optionally be called with a code block / lambda with the following signature:
#
#     lookup(...) |$name| { ... }
#
# The block, if present, is mutually exclusive to the `default_value` and will be called with the `name` used in
# in the lookup when no value is found. The value produced by the block then becomes the value produced by the
# lookup.
#
# When a block is used, it is the users responsibility to call `error` if an undef value is not acceptable.
#
# The content of the options hash is:
#
# * `name` - The name or array of names to lookup (first found is returned)
# * `value_type` - The type to assert (a Type or a type specification in string form)
# * `default_value` - The default value if there was no value found (must comply with the data type)
# * `accept_undef` - (default `false`) An `undef` result is accepted if this options is set to `true`.
# * `override` - a hash with map from names to values that are used instead of the underlying bindings. If the name
#   is found here it wins. Defaults to an empty hash.
# * `extra` - a hash with map from names to values that are used as a last resort to obtain a value. Defaults to an
#   empty hash.
# * `merge` - a string or a hash denoting merge strategy. A string that is one of'unique', 'hash', or 'merge' or
#    a hash with the key 'strategy' set to that string. The hash may then contain additional options for the given
#    strategy.
#
# It is not permitted to pass the `name` as both a parameter and in the options hash.
#
# The search will proceed as follows:
# For each name given in the `name` array (or once, if it's just one name):
#  - If an override is found, it's returned
#  - Search and optionally merge `global` (hiera), `environment`, and `module`
#  - Return if a value is found
#
# Again, for each name given in the `name` array (or once, if it's just one name):
#  - If an extra entry is found, it's returned
#
# Finally, fall back to default (or a given code block).
#
# The `merge` strategies are:
#  - 'hash' Perform a native Ruby Hash.merge. Arguments must be Hash.
#  - 'unique' Append everything to an array, and do a flatten and a unique at the end. Arguments can be Array or scalar.
#  - 'deep' Perform deep_merge on arrays and hashes using DeepMerge.deep_merge with options. Arguments must be Hash or Array
#
# The type specification is one of:
#
#   * A type in the Puppet Type System, e.g.:
#     * `Integer`, an integral value with optional range e.g.:
#       * `Integer[0, default]` - 0 or positive
#       * `Integer[default, -1]` - negative,
#       * `Integer[1,100]` - value between 1 and 100 inclusive
#     * `String`- any string
#     * `Float` - floating point number (same signature as for Integer for `Integer` ranges)
#     * `Boolean` - true of false (strict)
#     * `Array` - an array (of Data by default), or parameterized as `Array[<element_type>]`, where
#       `<element_type>` is the expected type of elements
#     * `Hash`,  - a hash (of default `Literal` keys and `Data` values), or parameterized as
#       `Hash[<value_type>]`, `Hash[<key_type>, <value_type>]`, where `<key_type>`, and
#       `<value_type>` are the types of the keys and values respectively
#       (key is `Literal` by default).
#     * `Data` - abstract type representing any `Literal`, `Array[Data]`, or `Hash[Literal, Data]`
#     * `Pattern[<p1>, <p2>, ..., <pn>]` - an enumeration of valid patterns (one or more) where
#        a pattern is a regular expression string or regular expression,
#        e.g. `Pattern['.com$', '.net$']`, `Pattern[/[a-z]+[0-9]+/]`
#     * `Enum[<s1>, <s2>, ..., <sn>]`, - an enumeration of exact string values (one or more)
#        e.g. `Enum[blue, red, green]`.
#     * `Variant[<t1>, <t2>,...<tn>]` - matches one of the listed types (at least one must be given)
#       e.g. `Variant[Integer[8000,8999], Integer[20000, 99999]]` to accept a value in either range
#     * `Regexp`- a regular expression (i.e. the result is a regular expression, not a string
#        matching a regular expression).
#   * A string containing a type description - one of the types as shown above but in string form.
#
# If the function is called without specifying a default value, and nothing is bound to the given name
# an error is raised unless the option `accept_undef` is true. If a block is given it must produce an acceptable
# value (or call `error`). If the block does not produce an acceptable value an error is
# raised.
#
# Examples:
#
# When called with one argument; **the name**, it
# returns the bound value with the given name after having  asserted it has the default datatype `Data`:
#
#     lookup('the_name')
#
# When called with two arguments; **the name**, and **the expected type**, it
# returns the bound value with the given name after having asserted it has the given data
# type ('String' in the example):
#
#     lookup('the_name', 'String')
#     lookup('the_name', String)
#
# When called with three arguments, **the name**, the **expected type**, and a **default**, it
# returns the bound value with the given name, or the default after having asserted the value
# has the given data type (`String` in the example above):
#
#     lookup('the_name', 'String', 'Fred')
#     lookup('the_name', String, 'Fred')
#
# Using a lambda to provide a default value by calling a function:
#
#     lookup('the_size', Integer[1,100]) |$name| {
#       obtain_size_default()
#     }
#
# When using a block, the value it produces is also asserted against the given type, and it may not be
# `undef` unless the option `'accept_undef'` is `true`.
#
# If you want to make lookup return undef when no value was found instead of raising an error:
#
#      $are_you_there = lookup('peekaboo', { accept_undef => true} )
#
# - Since 4.0.0
Puppet::Functions.create_function(:lookup, Puppet::Functions::InternalFunction) do
  name_t = 'Variant[String,Array[String]]'
  value_type_t = 'Optional[Variant[String,Type]]'
  default_value_t = 'Any'
  accept_undef_t = 'Boolean'
  override_t = 'Hash[String,Any]'
  extra_t = 'Hash[String,Any]'
  merge_t = 'Variant[String[1],Hash[String,Scalar]]'
  block_t = "Callable[#{name_t}]"
  option_pairs =
      "value_type=>#{value_type_t},"\
      "default_value=>Optional[#{default_value_t}],"\
      "accept_undef=>Optional[#{accept_undef_t}],"\
      "override=>Optional[#{override_t}],"\
      "extra=>Optional[#{extra_t}],"\
      "merge=>Optional[#{merge_t}]"\

  dispatch :lookup_1 do
    scope_param
    param name_t, :name
    param value_type_t, :value_type
    param default_value_t, :default_value
    param merge_t, :merge
    arg_count(1, 4)
  end

  dispatch :lookup_2 do
    scope_param
    param name_t, :name
    param value_type_t, :value_type
    param merge_t, :merge
    arg_count(1, 3)
    required_block_param block_t, :block
  end

  # Lookup without name. Name then becomes a required entry in the options hash
  dispatch :lookup_3 do
    scope_param
    param "Struct[{name=>#{name_t},#{option_pairs}}]", :options_hash
    optional_block_param block_t, :block
  end

  # Lookup using name and options hash.
  dispatch :lookup_4 do
    scope_param
    param 'Variant[String,Array[String]]', :name
    param "Struct[{#{option_pairs}}]", :options_hash
    optional_block_param block_t, :block
  end

  def lookup_1(scope, name, value_type=nil, default_value=nil, merge=nil)
    Puppet::Pops::Binder::Lookup.lookup(scope, name, value_type, default_value, false, {}, {}, merge)
  end

  def lookup_2(scope, name, value_type=nil, merge=nil, &block)
    Puppet::Pops::Binder::Lookup.lookup(scope, name, value_type, nil, false, {}, {}, merge, &block)
  end

  def lookup_3(scope, options_hash, &block)
    Puppet::Pops::Binder::Lookup.lookup(scope, options_hash['name'], *hash_args(options_hash), &block)
  end

  def lookup_4(scope, name, options_hash, &block)
    Puppet::Pops::Binder::Lookup.lookup(scope, name, *hash_args(options_hash), &block)
  end

  def hash_args(options_hash)
    [
        options_hash['value_type'],
        options_hash['default_value'],
        options_hash['accept_undef'] || false,
        options_hash['override'] || {},
        options_hash['extra'] || {},
        options_hash['merge']
    ]
  end
end
