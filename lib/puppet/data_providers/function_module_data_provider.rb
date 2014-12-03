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
  MODULE_NAME = 'module_name'.freeze
  include Puppet::DataProviders::DataFunctionSupport

  def lookup(name, scope)
    # If the module name does not exist, this call is not from within a module, and should be ignored.
    unless scope.exist?(MODULE_NAME)
      return nil
    end
    # Get the module name. Calls to the lookup method should only be performed for modules that have opted in
    # by specifying that they use the 'function' implementation as the module_data provider. Thus, this will error
    # out if a module specified 'function' but did not provide a function called <module-name>::data
    #
    module_name = scope[MODULE_NAME]
    begin
      data(module_name, scope)[name]
    rescue *Puppet::Error => detail
      raise Puppet::DataBinding::LookupError.new(detail.message, detail)
    end
  end

  def loader(scope)
    loaders = scope.compiler.loaders
    if scope.exist?(MODULE_NAME)
      loaders.private_loader_for_module(scope[MODULE_NAME])
    else
      # Produce the environment's loader when not in a module
      # This loader allows the data function to be private or public in the environment
      loaders.private_environment_loader
    end
  end
end
