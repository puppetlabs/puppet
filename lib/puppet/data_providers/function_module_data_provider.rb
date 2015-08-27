# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require_relative 'data_function_support'
module Puppet::DataProviders; end

# The FunctionModuleDataProvider provides data from a function called 'environment::data()' that resides in a
# directory environment (seen as a module with the name environment).
# The function is called on demand, and is associated with the compiler via an Adapter. This ensures that the data
# is only produced once per compilation.
#
class Puppet::DataProviders::FunctionModuleDataProvider < Puppet::Plugins::DataProviders::ModuleDataProvider
  include Puppet::DataProviders::DataFunctionSupport

  def loader(key, scope)
    scope.compiler.loaders.private_loader_for_module(key)
  end
end
