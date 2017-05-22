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
    if config.version > 3
      config
    else
      if Puppet[:strict] == :error
        config.fail(Issues::HIERA_VERSION_3_NOT_GLOBAL, :where => 'environment')
      else
        Puppet.warn_once(:hiera_v3_at_env_root, config.config_path, _('hiera.yaml version 3 found at the environment root was ignored'), config.config_path)
      end
      nil
    end
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
