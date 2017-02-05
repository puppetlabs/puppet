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
      require 'hiera/scope'
      # Hiera version 3 needs access to special scope variables
      scope = lookup_invocation.scope
      unless scope.is_a?(Hiera::Scope)
        lookup_invocation = Invocation.new(
          Hiera::Scope.new(scope),
          lookup_invocation.override_values,
          lookup_invocation.default_values,
          lookup_invocation.explainer)
      end
      merge = config.merge_strategy if merge.is_a?(DefaultMergeStrategy)
    end
    super(key, lookup_invocation, merge)
  end

  protected

  def assert_config_version(config)
    raise Puppet::DataBinding::LookupError, "#{config.name} cannot be used in the global layer" if config.version == 4
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
