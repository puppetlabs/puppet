# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require_relative 'data_function_support'
module Puppet::DataProviders; end

# The FunctionModuleDataProvider provides data from a function called 'environment::data()' that resides in a
# directory environment (seen as a module with the name environment).
# The function is called on demand, and is associated with the compiler via an Adapter. This ensures that the data
# is only produced once per compilation.
#
# TODO: API 5.0, remove this class
# @api private
# @deprecated
class Puppet::DataProviders::FunctionModuleDataProvider < Puppet::Plugins::DataProviders::ModuleDataProvider
  include Puppet::DataProviders::DataFunctionSupport

  def loader(key, scope)
    unless Puppet[:strict] == :off
      Puppet.warn_once(:deprecation, 'Puppet::DataProviders::FunctionModuleDataProvider',
      'Puppet::DataProviders::FunctionModuleDataProvider is deprecated and will be removed in the next major version of Puppet')
    end
    scope.compiler.loaders.private_loader_for_module(key)
  end
end
