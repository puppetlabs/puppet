require_relative 'hiera_config'

module Puppet::DataProviders::HieraSupport
  # Performs a lookup by searching all given paths for the given _key_. A merge will be performed if
  # the value is found in more than one location and _merge_ is not nil.
  #
  # @param key [String] The key to lookup
  # @param lookup_invocation [Puppet::DataBinding::LookupInvocation] The current lookup invocation
  # @param merge [String|Hash<String,Object>|nil] Merge strategy or hash with strategy and options
  #
  # @api public
  def unchecked_lookup(key, lookup_invocation, merge)
    result = Puppet::Pops::MergeStrategy.strategy(merge).merge_lookup(data_providers(data_key(key), lookup_invocation)) do |data_provider|
      data_provider.unchecked_lookup(key, lookup_invocation, merge)
    end
    throw :no_such_key if result.equal?(Puppet::Pops::MergeStrategy::NOT_FOUND)
    result
  end

  def data_providers(data_key, lookup_invocation)
    @data_providers ||= Puppet::DataProviders::HieraConfig.new(provider_root(data_key, lookup_invocation.scope)).create_data_providers(lookup_invocation)
  end
  private :data_providers
end
