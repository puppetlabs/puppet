require 'hiera_puppet'

# Provides the base class for the puppet functions hiera, hiera_array, hiera_hash, and hiera_include.
# The actual function definitions will call init_dispatch and override the merge_type and post_lookup methods.
#
# @see hiera_array.rb, hiera_include.rb under lib/puppet/functions for sample usage
#
class Hiera::PuppetFunction < Puppet::Functions::InternalFunction
  def self.init_dispatch
    dispatch :hiera_splat do
      scope_param
      param 'Tuple[String, Any, Any, 1, 3]', :args
    end

    dispatch :hiera_no_default do
      scope_param
      param 'String',:key
    end

    dispatch :hiera_with_default do
      scope_param
      param 'String',:key
      param 'Any',   :default
      optional_param 'Any',   :override
    end

    dispatch :hiera_block1 do
      scope_param
      param 'String',              :key
      block_param 'Callable[1,1]', :default_block
    end

    dispatch :hiera_block2 do
      scope_param
      param 'String',              :key
      param 'Any',                 :override
      block_param 'Callable[1,1]', :default_block
    end
  end

  def hiera_splat(scope, args)
    hiera(scope, *args)
  end

  def hiera_no_default(scope, key)
    post_lookup(scope, key, lookup(scope, key, nil, nil))
  end

  def hiera_with_default(scope, key, default, override = nil)
    undefined = (@@undefined_value ||= Object.new)
    result = lookup(scope, key, undefined, override)
    post_lookup(scope, key, result.equal?(undefined) ? default : result)
  end

  def hiera_block1(scope, key, &default_block)
    common(scope, key, nil, default_block)
  end

  def hiera_block2(scope, key, override, &default_block)
    common(scope, key, override, default_block)
  end

  def common(scope, key, override, default_block)
    undefined = (@@undefined_value ||= Object.new)
    result = lookup(scope, key, undefined, override)
    post_lookup(scope, key, result.equal?(undefined) ? default_block.call(key) : result)
  end

  private :common

  def lookup(scope, key, default, override)
    HieraPuppet.lookup(key, default, scope, override, merge_type)
  end

  def merge_type
    :priority
  end

  def post_lookup(scope, key, result)
    result
  end
end
