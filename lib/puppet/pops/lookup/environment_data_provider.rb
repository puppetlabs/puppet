require_relative 'configured_data_provider'

module Puppet::Pops
module Lookup
# @api private
class EnvironmentDataProvider < ConfiguredDataProvider
  def place
    'Environment'
  end

  protected

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
