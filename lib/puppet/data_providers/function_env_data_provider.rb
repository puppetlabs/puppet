# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require_relative 'data_function_support'
module Puppet::DataProviders; end

# The FunctionEnvDataProvider provides data from a function called 'environment::data()' that resides in a
# directory environment (seen as a module with the name environment).
# The function is called on demand, and is associated with the compiler via an Adapter. This ensures that the data
# is only produced once per compilation.
#
# TODO: API 5.0, remove this class
# @api private
# @deprecated
class Puppet::DataProviders::FunctionEnvDataProvider < Puppet::Plugins::DataProviders::EnvironmentDataProvider
  include Puppet::DataProviders::DataFunctionSupport

  def loader(key, scope)
    unless Puppet[:strict] == :off
      Puppet.warn_once(:deprecation, 'Puppet::DataProviders::FunctionEnvDataProvider',
        'Puppet::DataProviders::FunctionEnvDataProvider is deprecated and will be removed in the next major version of Puppet')
    end

    # This loader allows the data function to be private or public in the environment
    scope.compiler.loaders.private_environment_loader
  end
end
