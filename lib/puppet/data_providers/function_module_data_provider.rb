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

  def lookup(name, scope, merge)
    # Do not attempt to do a lookup in a module unless the name is qualified.
    qual_index = name.index('::')
    throw :no_such_key if qual_index.nil?
    module_name = name[0..qual_index-1]
    begin
      hash = data(module_name, scope) do | data |
        module_prefix = "#{module_name}::"
        data.each_pair do |k,v|
          unless k.is_a?(String) && k.start_with?(module_prefix)
            raise Puppet::Error, "Module data for module '#{module_name}' must use keys qualified with the name of the module"
          end
        end
      end
      throw :no_such_key unless hash.include?(name)
      hash[name]
    rescue *Puppet::Error => detail
      raise Puppet::DataBinding::LookupError.new(detail.message, detail)
    end
  end

  def loader(key, scope)
    scope.compiler.loaders.private_loader_for_module(key)
  end
end
