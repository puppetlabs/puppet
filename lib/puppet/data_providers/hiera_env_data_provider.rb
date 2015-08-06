# This file is loaded by the autoloader, and it does not find the hiera support unless required relative
require_relative 'hiera_support'

module Puppet::DataProviders
  class HieraEnvDataProvider < Puppet::Plugins::DataProviders::EnvironmentDataProvider
    include HieraSupport

    # Return the root of the environment found in the given _scope_
    #
    # @param data_key [String] not used
    # @param scope [Puppet::Parser::Scope] the parser scope where the environment is found
    # @return [Pathname] Path to root of the environment
    def provider_root(_, scope)
      Pathname.new(scope.environment.configuration.path_to_env)
    end
    protected :provider_root
  end
end
