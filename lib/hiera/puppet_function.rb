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
    post_lookup(scope, key, lookup(scope, key, nil, false, nil))
  end

  def hiera_with_default(scope, key, default, override = nil)
    post_lookup(scope, key, lookup(scope, key, default, true, override))
  end

  def hiera_block1(scope, key, &default_block)
    post_lookup(scope, key, lookup(scope, key, nil, false, nil, &default_block))
  end

  def hiera_block2(scope, key, override, &default_block)
    post_lookup(scope, key, lookup(scope, key, nil, false, override, &default_block))
  end

  def lookup(scope, key, default, has_default, override, &default_block)
    unless Puppet[:strict] == :off
      #TRANSLATORS 'lookup' is a puppet function and should not be translated
      message = _("The function '%{class_name}' is deprecated in favor of using 'lookup'.") % { class_name: self.class.name }
      message += ' '+ _("See https://docs.puppet.com/puppet/%{minor_version}/reference/deprecated_language.html") %
          { minor_version: Puppet.minor_version }
      Puppet.warn_once('deprecations', self.class.name, message)
    end
    lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {})
    adapter = lookup_invocation.lookup_adapter
    lookup_invocation.set_hiera_xxx_call
    lookup_invocation.set_global_only unless adapter.global_only? || adapter.has_environment_data_provider?(lookup_invocation)
    lookup_invocation.set_hiera_v3_location_overrides(override) unless override.nil? || override.is_a?(Array) && override.empty?
    Puppet::Pops::Lookup.lookup(key, nil, default, has_default, merge_type, lookup_invocation, &default_block)
  end

  def merge_type
    :first
  end

  def post_lookup(scope, key, result)
    result
  end
end
