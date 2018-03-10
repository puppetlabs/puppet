require 'hiera/puppet_function'

# Finds all matches of a key throughout the hierarchy and returns them as a single flattened
# array of unique values. If any of the matched values are arrays, they're flattened and
# included in the results. This is called an
# [array merge lookup](https://docs.puppetlabs.com/hiera/latest/lookup_types.html#array-merge).
#
# This function is deprecated in favor of the `lookup` function. While this function
# continues to work, it does **not** support:
# * `lookup_options` stored in the data
# * lookup across global, environment, and module layers
#
# The `hiera_array` function takes up to three arguments, in this order:
#
# 1. A string key that Hiera searches for in the hierarchy. **Required**.
# 2. An optional default value to return if Hiera doesn't find anything matching the key.
#     * If this argument isn't provided and this function results in a lookup failure, Puppet
#     fails with a compilation error.
# 3. The optional name of an arbitrary
# [hierarchy level](https://docs.puppetlabs.com/hiera/latest/hierarchy.html) to insert at the
# top of the hierarchy. This lets you temporarily modify the hierarchy for a single lookup.
#     * If Hiera doesn't find a matching key in the overriding hierarchy level, it continues
#     searching the rest of the hierarchy.
#
# @example Using `hiera_array`
#
# ```yaml
# # Assuming hiera.yaml
# # :hierarchy:
# #   - web01.example.com
# #   - common
#
# # Assuming common.yaml:
# # users:
# #   - 'cdouglas = regular'
# #   - 'efranklin = regular'
#
# # Assuming web01.example.com.yaml:
# # users: 'abarry = admin'
# ```
#
# ```puppet
# $allusers = hiera_array('users', undef)
#
# # $allusers contains ["cdouglas = regular", "efranklin = regular", "abarry = admin"].
# ```
#
# You can optionally generate the default value with a
# [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html) that
# takes one parameter.
#
# @example Using `hiera_array` with a lambda
#
# ```puppet
# # Assuming the same Hiera data as the previous example:
#
# $allusers = hiera_array('users') | $key | { "Key \'${key}\' not found" }
#
# # $allusers contains ["cdouglas = regular", "efranklin = regular", "abarry = admin"].
# # If hiera_array couldn't match its key, it would return the lambda result,
# # "Key 'users' not found".
# ```
#
# `hiera_array` expects that all values returned will be strings or arrays. If any matched
# value is a hash, Puppet raises a type mismatch error.
#
# See
# [the 'Using the lookup function' documentation](https://docs.puppet.com/puppet/latest/hiera_use_function.html) for how to perform lookup of data.
# Also see
# [the 'Using the deprecated hiera functions' documentation](https://docs.puppet.com/puppet/latest/hiera_use_hiera_functions.html)
# for more information about the Hiera 3 functions.
#
# @since 4.0.0
#
Puppet::Functions.create_function(:hiera_array, Hiera::PuppetFunction) do
  init_dispatch

  def merge_type
    :unique
  end
end
