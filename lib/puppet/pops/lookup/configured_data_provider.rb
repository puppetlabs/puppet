require_relative 'hiera_config'
require_relative 'data_provider'

module Puppet::Pops
module Lookup
# @api private
class ConfiguredDataProvider
  include DataProvider

  # @param config [HieraConfig,nil] the configuration
  def initialize(config = nil)
    @config = config.nil? ? nil : assert_config_version(config)
  end

  def config(lookup_invocation)
    @config ||= assert_config_version(HieraConfig.create(lookup_invocation, configuration_path(lookup_invocation), self))
  end

  # Needed to assign generated version 4 config
  # @deprecated
  def config=(config)
    @config = config
  end

  # @return [Pathname] the path to the configuration
  def config_path
    @config.nil? ? nil : @config.config_path
  end

  # @return [String] the name of this provider
  def name
    n = "#{place} "
    n << '"' << module_name << '" ' unless module_name.nil?
    n << 'Data Provider'
    n << " (#{@config.name})" unless @config.nil?
    n
  end

  # Performs a lookup by searching all configured locations for the given _key_. A merge will be performed if
  # the value is found in more than one location.
  #
  # @param key [String] The key to lookup
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param merge [MergeStrategy,String,Hash{String => Object},nil] Merge strategy, merge strategy name, strategy and options hash, or nil (implies "first found")
  # @return [Object] the found object
  # @throw :no_such_key when the object is not found
  def unchecked_key_lookup(key, lookup_invocation, merge)
    lookup_invocation.with(:data_provider, self) do
      merge_strategy = MergeStrategy.strategy(merge)
      dps = data_providers(lookup_invocation)
      if dps.empty?
        lookup_invocation.report_not_found(key)
        throw :no_such_key
      end
      merge_strategy.lookup(dps, lookup_invocation) do |data_provider|
        data_provider.unchecked_key_lookup(key, lookup_invocation, merge_strategy)
      end
    end
  end

  protected

  # Assert that the given config version is accepted by this data provider.
  #
  # @param config [HieraConfig] the configuration to check
  # @return [HieraConfig] the argument
  # @raise [Puppet::DataBinding::LookupError] if the configuration version is unacceptable
  def assert_config_version(config)
    config
  end

  # Return the root of the configured entity
  #
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @return [Pathname] Path to root of the module
  # @raise [Puppet::DataBinding::LookupError] if the given module is can not be found
  #
  def provider_root(lookup_invocation)
    raise NotImplementedError, "#{self.class.name} must implement method '#provider_root'"
  end

  def configuration_path(lookup_invocation)
    provider_root(lookup_invocation) + HieraConfig::CONFIG_FILE_NAME
  end

  private

  def data_providers(lookup_invocation)
    config(lookup_invocation).configured_data_providers(lookup_invocation, self)
  end
end
end
end
