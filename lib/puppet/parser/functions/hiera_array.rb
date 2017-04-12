require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(
    :hiera_array,
    :type => :rvalue,
    :arity => -2,
    :doc => <<-DOC
Finds all matches of a key throughout the hierarchy and returns them as a single flattened
array of unique values. If any of the matched values are arrays, they're flattened and
included in the results. This is called an
[array merge lookup](https://docs.puppetlabs.com/hiera/latest/lookup_types.html#array-merge).

The `hiera_array` function takes up to three arguments, in this order:

1. A string key that Hiera searches for in the hierarchy. **Required**.
2. An optional default value to return if Hiera doesn't find anything matching the key.
    * If this argument isn't provided and this function results in a lookup failure, Puppet
    fails with a compilation error.
3. The optional name of an arbitrary
[hierarchy level](https://docs.puppetlabs.com/hiera/latest/hierarchy.html) to insert at the
top of the hierarchy. This lets you temporarily modify the hierarchy for a single lookup.
    * If Hiera doesn't find a matching key in the overriding hierarchy level, it continues
    searching the rest of the hierarchy.

**Example**: Using `hiera_array`

~~~ yaml
# Assuming hiera.yaml
# :hierarchy:
#   - web01.example.com
#   - common

# Assuming common.yaml:
# users:
#   - 'cdouglas = regular'
#   - 'efranklin = regular'

# Assuming web01.example.com.yaml:
# users: 'abarry = admin'
~~~

~~~ puppet
$allusers = hiera_array('users', undef)

# $allusers contains ["cdouglas = regular", "efranklin = regular", "abarry = admin"].
~~~

You can optionally generate the default value with a
[lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html) that
takes one parameter.

**Example**: Using `hiera_array` with a lambda

~~~ puppet
# Assuming the same Hiera data as the previous example:

$allusers = hiera_array('users') | $key | { "Key \'${key}\' not found" }

# $allusers contains ["cdouglas = regular", "efranklin = regular", "abarry = admin"].
# If hiera_array couldn't match its key, it would return the lambda result,
# "Key 'users' not found".
~~~

`hiera_array` expects that all values returned will be strings or arrays. If any matched
value is a hash, Puppet raises a type mismatch error.

`hiera_array` is deprecated in favor of using `lookup` and will be removed in 6.0.0.
See  https://docs.puppet.com/puppet/#{Puppet.minor_version}/reference/deprecated_language.html.
Replace the calls as follows:

| from  | to |
| ----  | ---|
| hiera_array($key) | lookup($key, { 'merge' => 'unique' }) |
| hiera_array($key, $default) | lookup($key, { 'default_value' => $default, 'merge' => 'unique' }) |
| hiera_array($key, $default, $level) | override level not supported |

Note that calls using the 'override level' option are not directly supported by 'lookup' and the produced
result must be post processed to get exactly the same result, for example using simple hash/array `+` or
with calls to stdlib's `deep_merge` function depending on kind of hiera call and setting of merge in hiera.yaml.

See
[the documentation](https://docs.puppetlabs.com/hiera/latest/puppet.html#hiera-lookup-functions)
for more information about Hiera lookup functions.

- Since 4.0.0
DOC
) do |*args|
    Error.is4x('hiera_array')
  end
end

