require_relative 'hiera_config'

module Puppet::DataProviders::HieraSupport
  def config_path
    @hiera_config.nil? ? 'not yet configured' : @hiera_config.config_path
  end

  def name
    'Hiera Data Provider' + (@hiera_config.nil? ? '' : ", version #{@hiera_config.version}")
  end

  # Performs a lookup by searching all given paths for the given _key_. A merge will be performed if
  # the value is found in more than one location and _merge_ is not nil.
  #
  # @param key [String] The key to lookup
  # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
  # @param merge [Puppet::Pops::MergeStrategy,String,Hash<String,Object>,nil] Merge strategy or hash with strategy and options
  #
  # @api public
  def unchecked_lookup(key, lookup_invocation, merge)
    lookup_invocation.with(:data_provider, self) do
      merge_strategy = Puppet::Pops::MergeStrategy.strategy(merge)
      lookup_invocation.with(:merge, merge_strategy) do
        merged_result = merge_strategy.merge_lookup(data_providers(data_key(key, lookup_invocation), lookup_invocation)) do |data_provider|
          data_provider.unchecked_lookup(key, lookup_invocation, merge_strategy)
        end
        lookup_invocation.report_result(merged_result)
      end
    end
  end

  def data_providers(data_key, lookup_invocation)
    @hiera_config ||= Puppet::DataProviders::HieraConfig.new(provider_root(data_key, lookup_invocation.scope))
    @data_providers ||= @hiera_config.create_configured_data_providers(lookup_invocation, self)
  end
  private :data_providers
end
