require_relative 'configured_data_provider'

module Puppet::Pops
module Lookup
# @api private
class ModuleDataProvider < ConfiguredDataProvider

  attr_reader :module_name

  def initialize(module_name, config = nil)
    super(config)
    @module_name = module_name
  end

  def place
    'Module'
  end

  # Asserts that all keys in the given _data_hash_ are prefixed with the configured _module_name_. Removes entries
  # that does not follow the convention and logs a warning.
  #
  # @param data_hash [Hash] The data hash
  # @return [Hash] The possibly pruned hash
  def validate_data_hash(data_provider, data_hash)
    super
    module_prefix = "#{module_name}::"
    data_hash.each_key.reduce(data_hash) do |memo, k|
      next memo if k == LOOKUP_OPTIONS || k.start_with?(module_prefix)
      msg = 'must use keys qualified with the name of the module'
      memo = memo.clone if memo.equal?(data_hash)
      memo.delete(k)
      Puppet.warning("Module '#{module_name}': #{data_provider.name} #{msg}")
      memo
    end
  end

  protected

  # Return the root of the module with the name equal to the configured module name
  #
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @return [Pathname] Path to root of the module
  # @raise [Puppet::DataBinder::LookupError] if the module can not be found
  #
  def provider_root(lookup_invocation)
    env = lookup_invocation.scope.environment
    mod = env.module(module_name)
    raise Puppet::DataBinder::LookupError, "Environment '#{env.name}', cannot find module '#{module_name}'" unless mod
    Pathname.new(mod.path)
  end
end
end
end
