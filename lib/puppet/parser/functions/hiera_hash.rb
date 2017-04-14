require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(
    :hiera_hash,
    :type => :rvalue,
    :arity => -2,
    :doc => <<-DOC
Finds all matches of a key throughout the hierarchy and returns them in a merged hash.
If any of the matched hashes share keys, the final hash uses the value from the
highest priority match. This is called a
[hash merge lookup](https://docs.puppetlabs.com/hiera/latest/lookup_types.html#hash-merge).

The merge strategy is determined by Hiera's
[`:merge_behavior`](https://docs.puppetlabs.com/hiera/latest/configuring.html#mergebehavior)
setting.

The `hiera_hash` function takes up to three arguments, in this order:

1. A string key that Hiera searches for in the hierarchy. **Required**.
2. An optional default value to return if Hiera doesn't find anything matching the key.
    * If this argument isn't provided and this function results in a lookup failure, Puppet
    fails with a compilation error.
3. The optional name of an arbitrary
[hierarchy level](https://docs.puppetlabs.com/hiera/latest/hierarchy.html) to insert at the
top of the hierarchy. This lets you temporarily modify the hierarchy for a single lookup.
    * If Hiera doesn't find a matching key in the overriding hierarchy level, it continues
    searching the rest of the hierarchy.

**Example**: Using `hiera_hash`

~~~ yaml
# Assuming hiera.yaml
# :hierarchy:
#   - web01.example.com
#   - common

# Assuming common.yaml:
# users:
#   regular:
#     'cdouglas': 'Carrie Douglas'

# Assuming web01.example.com.yaml:
# users:
#   administrators:
#     'aberry': 'Amy Berry'
~~~

~~~ puppet
# Assuming we are not web01.example.com:

$allusers = hiera_hash('users', undef)

# $allusers contains {regular => {"cdouglas" => "Carrie Douglas"},
#                     administrators => {"aberry" => "Amy Berry"}}
~~~

You can optionally generate the default value with a
[lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html) that
takes one parameter.

**Example**: Using `hiera_hash` with a lambda

~~~ puppet
# Assuming the same Hiera data as the previous example:

$allusers = hiera_hash('users') | $key | { "Key \'${key}\' not found" }

# $allusers contains {regular => {"cdouglas" => "Carrie Douglas"},
#                     administrators => {"aberry" => "Amy Berry"}}
# If hiera_hash couldn't match its key, it would return the lambda result,
# "Key 'users' not found".
~~~

`hiera_hash` expects that all values returned will be hashes. If any of the values
found in the data sources are strings or arrays, Puppet raises a type mismatch error.

`hiera_hash` is deprecated in favor of using `lookup` and will be removed in 6.0.0.
See  https://docs.puppet.com/puppet/#{Puppet.minor_version}/reference/deprecated_language.html.
Replace the calls as follows:

| from  | to |
| ----  | ---|
| hiera_hash($key) | lookup($key, { 'merge' => 'hash' }) |
| hiera_hash($key, $default) | lookup($key, { 'default_value' => $default, 'merge' => 'hash' }) |
| hiera_hash($key, $default, $level) | override level not supported |

Note that calls using the 'override level' option are not directly supported by 'lookup' and the produced
result must be post processed to get exactly the same result, for example using simple hash/array `+` or
with calls to stdlib's `deep_merge` function depending on kind of hiera call and setting of merge in hiera.yaml.

See
[the documentation](https://docs.puppetlabs.com/hiera/latest/puppet.html#hiera-lookup-functions)
for more information about Hiera lookup functions.

- Since 4.0.0
DOC
  ) do |*args|
    Error.is4x('hiera_hash')
  end
end

