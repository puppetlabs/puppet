require_relative 'lookup_config'
require_relative 'data_provider'
require 'puppet/data_providers/hiera_config'

module Puppet::Pops
module Lookup
# @api private
class ConfiguredDataProvider
  include DataProvider

  # @param [LookupConfig,nil] config the configuration
  def initialize(config = nil)
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
      merge_strategy.lookup(data_providers(lookup_invocation), lookup_invocation) do |data_provider|
        data_provider.unchecked_key_lookup(key, lookup_invocation, merge_strategy)
      end
    end
  end

  protected

  # Return the root of the configured entity
  #
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @return [Pathname] Path to root of the module
  # @raise [Puppet::DataBinder::LookupError] if the given module is can not be found
  #
  def provider_root(lookup_invocation)
    raise NotImplementedError, "#{self.class.name} must implement method '#provider_root'"
  end

  private

  def data_providers(lookup_invocation)
    if @config.nil?
      config_path = provider_root(lookup_invocation)
      # TODO: API 5.0, remove use of deprecated HieraConfig
      if LookupConfig.config_exist?(config_path)
        @config = LookupConfig.new(config_path)
      elsif Puppet::DataProviders::HieraConfig.config_exist?(config_path)
        @config = Puppet::DataProviders::HieraConfig.new(config_path)
      else
        @config = LookupConfig.new(config_path)
      end
    end
    @data_providers ||= @config.create_configured_data_providers(lookup_invocation, self)
  end
end
end
end
