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

  # Performs a lookup using a module default hierarchy with an endless recursion check.
  #
  # @param key [LookupKey] The key to lookup
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param merge [MergeStrategy,String,Hash{String=>Object},nil] Merge strategy or hash with strategy and options
  #
  def key_lookup_in_default(key, lookup_invocation, merge)
    dps = config(lookup_invocation).configured_data_providers(lookup_invocation, self, true)
    if dps.empty?
      lookup_invocation.report_not_found(key)
      throw :no_such_key
    end
    merge_strategy = MergeStrategy.strategy(merge)
    lookup_invocation.check(key.to_s) do
      lookup_invocation.with(:data_provider, self) do
        merge_strategy.lookup(dps, lookup_invocation) do |data_provider|
          data_provider.unchecked_key_lookup(key, lookup_invocation, merge_strategy)
        end
      end
    end
  end

  # Asserts that all keys in the given _data_hash_ are prefixed with the configured _module_name_. Removes entries
  # that does not follow the convention and logs a warning.
  #
  # @param data_hash [Hash] The data hash
  # @return [Hash] The possibly pruned hash
  def validate_data_hash(data_hash)
    super
    module_prefix = "#{module_name}::"
    data_hash.each_key.reduce(data_hash) do |memo, k|
      next memo if k == LOOKUP_OPTIONS || k.start_with?(module_prefix)
      msg = "#{yield} must use keys qualified with the name of the module"
      memo = memo.clone if memo.equal?(data_hash)
      memo.delete(k)
      Puppet.warning("Module '#{module_name}': #{msg}")
      memo
    end
    data_hash
  end

  protected

  def assert_config_version(config)
    if config.version > 3
      config
    else
      if Puppet[:strict] == :error
        config.fail(Issues::HIERA_VERSION_3_NOT_GLOBAL, :where => 'module')
      else
        Puppet.warn_once(:hiera_v3_at_module_root, config.config_path, _('hiera.yaml version 3 found at module root was ignored'), config.config_path)
      end
      nil
    end
  end

  # Return the root of the module with the name equal to the configured module name
  #
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @return [Pathname] Path to root of the module
  # @raise [Puppet::DataBinding::LookupError] if the module can not be found
  #
  def provider_root(lookup_invocation)
    env = lookup_invocation.scope.environment
    mod = env.module(module_name)
    raise Puppet::DataBinding::LookupError, _("Environment '%{env}', cannot find module '%{module_name}'") % { env: env.name, module_name: module_name } unless mod
    Pathname.new(mod.path)
  end
end
end
end
