require 'hiera/puppet_function'

# Assigns classes to a node using an
# [array merge lookup](https://docs.puppetlabs.com/hiera/latest/lookup_types.html#array-merge)
# that retrieves the value for a user-specified key from Hiera's data.
#
# This function is deprecated in favor of the `lookup` function in combination with `include`.
# While this function continues to work, it does **not** support:
# * `lookup_options` stored in the data
# * lookup across global, environment, and module layers
#
# @example Using `lookup` and `include` instead of of the deprecated `hiera_include`
# 
# ```puppet
# # In site.pp, outside of any node definitions and below any top-scope variables:
# lookup('classes', Array[String], 'unique').include
# ```
#
# The `hiera_include` function requires:
#
# - A string key name to use for classes.
# - A call to this function (i.e. `hiera_include('classes')`) in your environment's
# `sites.pp` manifest, outside of any node definitions and below any top-scope variables
# that Hiera uses in lookups.
# - `classes` keys in the appropriate Hiera data sources, with an array for each
# `classes` key and each value of the array containing the name of a class.
#
# The function takes up to three arguments, in this order:
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
# The function uses an
# [array merge lookup](https://docs.puppetlabs.com/hiera/latest/lookup_types.html#array-merge)
# to retrieve the `classes` array, so every node gets every class from the hierarchy.
#
# @example Using `hiera_include`
#
# ```yaml
# # Assuming hiera.yaml
# # :hierarchy:
# #   - web01.example.com
# #   - common
#
# # Assuming web01.example.com.yaml:
# # classes:
# #   - apache::mod::php
#
# # Assuming common.yaml:
# # classes:
# #   - apache
# ```
#
# ```puppet
# # In site.pp, outside of any node definitions and below any top-scope variables:
# hiera_include('classes', undef)
#
# # Puppet assigns the apache and apache::mod::php classes to the web01.example.com node.
# ```
#
# You can optionally generate the default value with a
# [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html) that
# takes one parameter.
#
# @example Using `hiera_include` with a lambda
#
# ```puppet
# # Assuming the same Hiera data as the previous example:
#
# # In site.pp, outside of any node definitions and below any top-scope variables:
# hiera_include('classes') | $key | {"Key \'${key}\' not found" }
#
# # Puppet assigns the apache and apache::mod::php classes to the web01.example.com node.
# # If hiera_include couldn't match its key, it would return the lambda result,
# # "Key 'classes' not found".
# ```
#
# See
# [the 'Using the lookup function' documentation](https://docs.puppet.com/puppet/latest/hiera_use_function.html) for how to perform lookup of data.
# Also see
# [the 'Using the deprecated hiera functions' documentation](https://docs.puppet.com/puppet/latest/hiera_use_hiera_functions.html)
# for more information about the Hiera 3 functions.
#
# @since 4.0.0
#
Puppet::Functions.create_function(:hiera_include, Hiera::PuppetFunction) do
  init_dispatch

  def merge_type
    :unique
  end

  def post_lookup(scope, key, value)
    raise Puppet::ParseError, _("Could not find data item %{key}") % { key: key } if value.nil?
    call_function_with_scope(scope, 'include', value) unless value.empty?
  end
end
