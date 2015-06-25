require 'hiera/puppet_function'

# Assigns classes to a node using an array merge lookup that retrieves the value for a user-specified key
#   from a Hiera data source.
#
#  To use `hiera_include`, the following configuration is required:
#  - A key name to use for classes, e.g. `classes`.
#  - A line in the puppet `sites.pp` file (e.g. `/etc/puppet/manifests/sites.pp`)
#    reading `hiera_include('classes')`. Note that this line must be outside any node
#    definition and below any top-scope variables in use for Hiera lookups.
#  - Class keys in the appropriate data sources. In a data source keyed to a node's role,
#    one might have:
#
#            ---
#            classes:
#              - apache
#              - apache::passenger
#  The function can be called in one of three ways:
#  1. Using 1 to 3 arguments where the arguments are:
#     'key'      [String] Required
#           The key to lookup.
#     'default`  [Any] Optional
#           A value to return when there's no match for `key`. Optional
#     `override` [Any] Optional
#           An argument in the third position, providing a data source
#           to consult for matching values, even if it would not ordinarily be
#           part of the matched hierarchy. If Hiera doesn't find a matching key
#           in the named override data source, it will continue to search through the
#          rest of the hierarchy.
#
#  2. Using a 'key' and an optional 'override' parameter like in #1 but with a block to
#     provide the default value. The block is called with one parameter (the key) and
#     should return the array to be used in the subsequent call to include.
#
#  3. Like #1 but with all arguments passed in an array.
#
#  More thorough examples of `hiera_include` are available at:
#  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
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
