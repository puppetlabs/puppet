require_relative 'configured_data_provider'

module Puppet::Pops
module Lookup
# @api private
class EnvironmentDataProvider < ConfiguredDataProvider
  def place
    'Environment'
  end

  protected

  def assert_config_version(config)
    raise Puppet::DataBinding::LookupError, "#{config.name} cannot be used in an environment" unless config.version > 3
    config
  end

  # Return the root of the environment
  #
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @return [Pathname] Path to root of the environment
  def provider_root(lookup_invocation)
    Pathname.new(lookup_invocation.scope.environment.configuration.path_to_env)
  end
end
end
end
