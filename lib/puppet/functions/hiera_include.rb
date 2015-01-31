require 'hiera_puppet'

# Assigns classes to a node using an array merge lookup that retrieves the value for
# a user-specified key from a Hiera data source.
#
# To use `hiera_include`, the following configuration is required:
# - A key name to use for classes, e.g. `classes`.
# - A line in the puppet `sites.pp` file (e.g. `/etc/puppet/manifests/sites.pp`)
#   reading `hiera_include('classes')`. Note that this line must be outside any node
#   definition and below any top-scope variables in use for Hiera lookups.
# - Class keys in the appropriate data sources. In a data source keyed to a node's role,
#   one might have:
#
#       ---
#        classes:
#          - apache
#          - apache::passenger
#
# The function can be called in one of three ways:
# 1. Using 1 to 3 arguments where the arguments are:
#    'key'      [String] Required
#          The key to lookup.
#    'default`  [Any] Optional
#          A value to return when there's no match for `key`. Optional
#    `override` [Any] Optional
#          An argument in the third position, providing a data source
#          to consult for matching values, even if it would not ordinarily be
#          part of the matched hierarchy. If Hiera doesn't find a matching key
#          in the named override data source, it will continue to search through the
#          rest of the hierarchy.
#
# 2. Using a 'key' and an optional 'override' parameter like in #1 but with a block to
#    provide the default value.
#
# 3. Like #1 but with all arguments passed in an array.
#
#  More thorough examples of `hiera` are available at:
#  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
Puppet::Functions.create_function(:hiera_include, Puppet::Functions::InternalFunction) do
  dispatch :hiera_include_splat do
    scope_param
    param 'Tuple[String, Any, Any, 1, 3]', :args
  end

  dispatch :hiera_include do
    scope_param
    param 'String',:key
    param 'Any',   :default
    param 'Any',   :override
    arg_count(1,3)
  end

  dispatch :hiera_include_block do
    scope_param
    param 'String',        :key
    param 'Optional[Any]', :override
    required_block_param 'Callable[1,1]', :block
    arg_count(1,2)
  end

  def hiera_include_splat(scope, args)
    hiera_include(scope, *args)
  end

  def hiera_include(scope, key, default = nil, override = nil)
    do_include(key, lookup(scope, key, default, override))
  end

  def hiera_include_block(scope, key, override = nil, block)
    undefined = (@@undefined_value ||= Object.new)
    result = lookup(scope, key, undefined, override)
    do_include(key, result.equal?(undefined) ? block.call(scope, key) : result)
  end

  def lookup(scope, key, default, override)
    HieraPuppet.lookup(key, default,scope, override, :array)
  end

  def do_include(key, value)
    raise Puppet::ParseError, "Could not find data item #{key}" if value.nil?
    call_function('include', value) unless value.empty?
  end
end
