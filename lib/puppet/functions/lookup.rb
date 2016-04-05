# Uses the Puppet lookup system to retrieve a value for a given key. By default,
# this returns the first value found (and fails compilation if no values are
# available), but you can configure it to merge multiple values into one, fail
# gracefully, and more.
#
# When looking up a key, Puppet will search up to three tiers of data, in the
# following order:
#
# 1. Hiera.
# 2. The current environment's data provider.
# 3. The indicated module's data provider, if the key is of the form
#    `<MODULE NAME>::<SOMETHING>`.
#
# #### Arguments
#
# You must provide the name of a key to look up, and can optionally provide other
# arguments. You can combine these arguments in the following ways:
#
# * `lookup( <NAME>, [<VALUE TYPE>], [<MERGE BEHAVIOR>], [<DEFAULT VALUE>] )`
# * `lookup( [<NAME>], <OPTIONS HASH> )`
# * `lookup( as above ) |$key| { # lambda returns a default value }`
#
# Arguments in `[square brackets]` are optional.
#
# The arguments accepted by `lookup` are as follows:
#
# 1. `<NAME>` (string or array) --- The name of the key to look up.
#     * This can also be an array of keys. If Puppet doesn't find anything for the
#     first key, it will try again with the subsequent ones, only resorting to a
#     default value if none of them succeed.
# 2. `<VALUE TYPE>` (data type) --- A
# [data type](https://docs.puppetlabs.com/puppet/latest/reference/lang_data_type.html)
# that must match the retrieved value; if not, the lookup (and catalog
# compilation) will fail. Defaults to `Data` (accepts any normal value).
# 3. `<MERGE BEHAVIOR>` (string or hash; see **"Merge Behaviors"** below) ---
# Whether (and how) to combine multiple values. If present, this overrides any
# merge behavior specified in the data sources. Defaults to no value; Puppet will
# use merge behavior from the data sources if present, and will otherwise do a
# first-found lookup.
# 4. `<DEFAULT VALUE>` (any normal value) --- If present, `lookup` returns this
# when it can't find a normal value. Default values are never merged with found
# values. Like a normal value, the default must match the value type. Defaults to
# no value; if Puppet can't find a normal value, the lookup (and compilation) will
# fail.
# 5. `<OPTIONS HASH>` (hash) --- Alternate way to set the arguments above, plus
# some less-common extra options. If you pass an options hash, you can't combine
# it with any regular arguments (except `<NAME>`). An options hash can have the
# following keys:
#     * `'name'` --- Same as `<NAME>` (argument 1). You can pass this as an
#     argument or in the hash, but not both.
#     * `'value_type'` --- Same as `<VALUE TYPE>` (argument 2).
#     * `'merge'` --- Same as `<MERGE BEHAVIOR>` (argument 3).
#     * `'default_value'` --- Same as `<DEFAULT VALUE>` (argument 4).
#     * `'default_values_hash'` (hash) --- A hash of lookup keys and default
#     values. If Puppet can't find a normal value, it will check this hash for the
#     requested key before giving up. You can combine this with `default_value` or
#     a lambda, which will be used if the key isn't present in this hash. Defaults
#     to an empty hash.
#     * `'override'` (hash) --- A hash of lookup keys and override values. Puppet
#     will check for the requested key in the overrides hash _first;_ if found, it
#     returns that value as the _final_ value, ignoring merge behavior. Defaults
#     to an empty hash.
#
# Finally, `lookup` can take a lambda, which must accept a single parameter.
# This is yet another way to set a default value for the lookup; if no results are
# found, Puppet will pass the requested key to the lambda and use its result as
# the default value.
#
# #### Merge Behaviors
#
# Puppet lookup uses a hierarchy of data sources, and a given key might have
# values in multiple sources. By default, Puppet returns the first value it finds,
# but it can also continue searching and merge all the values together.
#
# > **Note:** Data sources can use the special `lookup_options` metadata key to
# request a specific merge behavior for a key. The `lookup` function will use that
# requested behavior unless you explicitly specify one.
#
# The valid merge behaviors are:
#
# * `'first'` --- Returns the first value found, with no merging. Puppet lookup's
# default behavior.
# * `'unique'` (called "array merge" in classic Hiera) --- Combines any number of
# arrays and scalar values to return a merged, flattened array with all duplicate
# values removed. The lookup will fail if any hash values are found.
# * `'hash'` --- Combines the keys and values of any number of hashes to return a
# merged hash. If the same key exists in multiple source hashes, Puppet will use
# the value from the highest-priority data source; it won't recursively merge the
# values.
# * `'deep'` --- Combines the keys and values of any number of hashes to return a
# merged hash. If the same key exists in multiple source hashes, Puppet will
# recursively merge hash or array values (with duplicate values removed from
# arrays). For conflicting scalar values, the highest-priority value will win.
# * `{'strategy' => 'first|unique|hash'}` --- Same as the string versions of these
# merge behaviors.
# * `{'strategy' => 'deep', <DEEP OPTION> => <VALUE>, ...}` --- Same as `'deep'`,
# but can adjust the merge with additional options. The available options are:
#     * `'knockout_prefix'` (string or undef) --- A string prefix to indicate a
#     value should be _removed_ from the final result. Defaults to `undef`, which
#     disables this feature.
#     * `'sort_merged_arrays'` (boolean) --- Whether to sort all arrays that are
#     merged together. Defaults to `false`.
#     * `'merge_hash_arrays'` (boolean) --- Whether to merge hashes within arrays.
#     Defaults to `false`.
#
# @example Look up a key and return the first value found
#
#     lookup('ntp::service_name')
#
# @example Do a unique merge lookup of class names, then add all of those classes to the catalog (like `hiera_include`)
#
#     lookup('classes', Array[String], 'unique').include
#
# @example Do a deep hash merge lookup of user data, but let higher priority sources remove values by prefixing them with `--`
#
#     lookup( { 'name'  => 'users',
#               'merge' => {
#                 'strategy'        => 'deep',
#                 'knockout_prefix' => '--',
#               },
#     })
#
# @since 4.0.0
Puppet::Functions.create_function(:lookup, Puppet::Functions::InternalFunction) do

  local_types do
    type 'NameType         = Variant[String, Array[String]]'
    type 'ValueType        = Type'
    type 'DefaultValueType = Any'
    type 'MergeType        = Variant[String[1], Hash[String, Scalar]]'
    type 'BlockType        = Callable[NameType]'
    type "OptionsWithName  = Struct[{\
      name                => NameType,\
      value_type          => Optional[ValueType],\
      default_value       => Optional[DefaultValueType],\
      override            => Optional[Hash[String,Any]],\
      default_values_hash => Optional[Hash[String,Any]],\
      merge               => Optional[MergeType]\
    }]"
    type "OptionsWithoutName = Struct[{\
      value_type          => Optional[ValueType],\
      default_value       => Optional[DefaultValueType],\
      override            => Optional[Hash[String,Any]],\
      default_values_hash => Optional[Hash[String,Any]],\
      merge               => Optional[MergeType]\
    }]"

  end

  dispatch :lookup_1 do
    scope_param
    param           'NameType',       :name
    optional_param  'ValueType',      :value_type
    optional_param  'MergeType',      :merge
  end

  dispatch :lookup_2 do
    scope_param
    param 'NameType',                 :name
    param 'Optional[ValueType]',      :value_type
    param 'Optional[MergeType]',      :merge
    param 'DefaultValueType',         :default_value
  end

  dispatch :lookup_3 do
    scope_param
    param                'NameType',   :name
    optional_param       'ValueType',  :value_type
    optional_param       'MergeType',  :merge
    required_block_param 'BlockType',  :block
  end

  # Lookup without name. Name then becomes a required entry in the options hash
  dispatch :lookup_4 do
    scope_param
    param                'OptionsWithName', :options_hash
    optional_block_param 'BlockType',       :block
  end

  # Lookup using name and options hash.
  dispatch :lookup_5 do
    scope_param
    param                'Variant[String,Array[String]]', :name
    param                'OptionsWithoutName',            :options_hash
    optional_block_param 'BlockType',                     :block
  end

  def lookup_1(scope, name, value_type=nil, merge=nil)
    do_lookup(scope, name, value_type, nil, false, {}, {}, merge)
  end

  def lookup_2(scope, name, value_type, merge, default_value)
    do_lookup(scope, name, value_type, default_value, true, {}, {}, merge)
  end

  def lookup_3(scope, name, value_type=nil, merge=nil, &block)
    do_lookup(scope, name, value_type, nil, false, {}, {}, merge, &block)
  end

  def lookup_4(scope, options_hash, &block)
    do_lookup(scope, options_hash['name'], *hash_args(options_hash), &block)
  end

  def lookup_5(scope, name, options_hash, &block)
    do_lookup(scope, name, *hash_args(options_hash), &block)
  end

  def do_lookup(scope, name, value_type, default_value, has_default, override, default_values_hash, merge, &block)
    Puppet::Pops::Lookup.lookup(name, value_type, default_value, has_default, merge, Puppet::Pops::Lookup::Invocation.new(scope, override, default_values_hash), &block)
  end

  def hash_args(options_hash)
    [
        options_hash['value_type'],
        options_hash['default_value'],
        options_hash.include?('default_value'),
        options_hash['override'] || {},
        options_hash['default_values_hash'] || {},
        options_hash['merge']
    ]
  end
end
