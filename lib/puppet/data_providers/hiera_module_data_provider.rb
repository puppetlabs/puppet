# This file is loaded by the autoloader, and it does not find the hiera support unless required relative
require_relative 'hiera_support'

module Puppet::DataProviders
  class HieraModuleDataProvider < Puppet::Plugins::DataProviders::ModuleDataProvider
    include HieraSupport

    # Return the root of the module with the name equal to _data_key_ found in the environment of the given _scope_
    #
    # @param data_key [String] the name of the module
    # @param scope [Puppet::Parser::Scope] the parser scope where the environment is found
    # @return [Pathname] Path to root of the environment
    # @raise [Puppet::DataBinder::LookupError] if the given module is can not be found
    #
    def provider_root(module_name, scope)
      env = scope.environment
      mod = env.modules.find { |m| m.name == module_name }
      raise Puppet::DataBinder::LookupError, "Environment '#{env.name}', cannot find module '#{module_name}'" unless mod
      Pathname.new(mod.path)
    end
    protected :provider_root
  end
end
