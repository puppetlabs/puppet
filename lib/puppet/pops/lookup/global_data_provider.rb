require 'hiera/scope'
require_relative 'configured_data_provider'

module Puppet::Pops
module Lookup
# @api private
class GlobalDataProvider < ConfiguredDataProvider
  def place
    'Global'
  end

  def unchecked_key_lookup(key, lookup_invocation, merge)
    config = config(lookup_invocation)
    if(config.version == 3)
      # Hiera version 3 needs access to special scope variables
      scope = lookup_invocation.scope
      unless scope.is_a?(Hiera::Scope)
        return lookup_invocation.with_scope(Hiera::Scope.new(scope)) do |hiera_invocation|

          # Confine to global scope unless an environment data provider has been defined (same as for hiera_xxx functions)
          adapter = lookup_invocation.lookup_adapter
          hiera_invocation.set_global_only unless adapter.global_only? || adapter.has_environment_data_provider?(lookup_invocation)
          hiera_invocation.lookup(key, lookup_invocation.module_name) { unchecked_key_lookup(key , hiera_invocation, merge) }
        end
      end

      merge = MergeStrategy.strategy(merge)
      unless config.merge_strategy.is_a?(DefaultMergeStrategy)
        if lookup_invocation.hiera_xxx_call? && merge.is_a?(HashMergeStrategy)
          # Merge strategy defined in the hiera config only applies when the call stems from a hiera_hash call.
          merge = config.merge_strategy
          lookup_invocation.set_hiera_v3_merge_behavior
        end
      end

      value = super(key, lookup_invocation, merge)
      if lookup_invocation.hiera_xxx_call?
        if merge.is_a?(HashMergeStrategy) || merge.is_a?(DeepMergeStrategy)
          # hiera_hash calls should error when found values are not hashes
          Types::TypeAsserter.assert_instance_of('value', Types::PHashType::DEFAULT, value)
        end
        if !key.segments.nil? && (merge.is_a?(HashMergeStrategy) || merge.is_a?(UniqueMergeStrategy))
          strategy = merge.is_a?(HashMergeStrategy) ? 'hash' : 'array'

          # Fail with old familiar message from Hiera 3
          raise Puppet::DataBinding::LookupError, "Resolution type :#{strategy} is illegal when accessing values using dotted keys. Offending key was '#{key}'"
        end
      end
      value
    else
      super
    end
  end

  protected

  def assert_config_version(config)
    config.fail(Issues::HIERA_UNSUPPORTED_VERSION_IN_GLOBAL) if config.version == 4
    config
  end

  # Return the root of the environment
  #
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @return [Pathname] Path to the parent of the hiera configuration file
  def provider_root(lookup_invocation)
    configuration_path(lookup_invocation).parent
  end

  def configuration_path(lookup_invocation)
    lookup_invocation.global_hiera_config_path
  end
end
end
end
