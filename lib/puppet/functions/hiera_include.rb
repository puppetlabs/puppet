require 'hiera/puppet_function'

# Assigns classes to a node using an
# [array merge lookup](https://docs.puppetlabs.com/hiera/latest/lookup_types.html#array-merge)
# that retrieves the value for a user-specified key from Hiera's data.
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
# ~~~ yaml
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
# ~~~
#
# ~~~ puppet
# # In site.pp, outside of any node definitions and below any top-scope variables:
# hiera_include('classes', undef)
#
# # Puppet assigns the apache and apache::mod::php classes to the web01.example.com node.
# ~~~
#
# You can optionally generate the default value with a
# [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html) that
# takes one parameter.
#
# @example Using `hiera_include` with a lambda
#
# ~~~ puppet
# # Assuming the same Hiera data as the previous example:
#
# # In site.pp, outside of any node definitions and below any top-scope variables:
# hiera_include('classes') | $key | {"Key \'${key}\' not found" }
#
# # Puppet assigns the apache and apache::mod::php classes to the web01.example.com node.
# # If hiera_include couldn't match its key, it would return the lambda result,
# # "Key 'classes' not found".
# ~~~
#
# See [the documentation](http://links.puppetlabs.com/hierainclude) for more information
# and a more detailed example of how `hiera_include` uses array merge lookups to classify
# nodes.
#
# @since 4.0.0
#
Puppet::Functions.create_function(:hiera_include, Hiera::PuppetFunction) do
  init_dispatch

  def merge_type
    :array
  end

  def post_lookup(scope, key, value)
    raise Puppet::ParseError, "Could not find data item #{key}" if value.nil?
    call_function_with_scope(scope, 'include', value) unless value.empty?
  end
end
