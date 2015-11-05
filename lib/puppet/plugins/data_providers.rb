module Puppet::Plugins; end

module Puppet::Plugins::DataProviders

  # The lookup **key** for the multibind containing data provider name per module
  # @api public
  PER_MODULE_DATA_PROVIDER_KEY       = 'puppet::module_data'

  # The lookup **type** for the name of the per module data provider.
  # @api public
  PER_MODULE_DATA_PROVIDER_TYPE      = String

  # The lookup **key** for the multibind containing map of provider name to env data provider implementation.
  # @api public
  ENV_DATA_PROVIDERS_KEY             = 'puppet::environment_data_providers'

  # The lookup **type** for the multibind containing map of provider name to env data provider implementation.
  # @api public
  ENV_DATA_PROVIDERS_TYPE            = 'Puppet::Plugins::DataProviders::EnvironmentDataProvider'

  # The lookup **key** for the multibind containing map of provider name to module data provider implementation.
  # @api public
  MODULE_DATA_PROVIDERS_KEY          = 'puppet::module_data_providers'

  # The lookup **type** for the multibind containing map of provider name to module data provider implementation.
  # @api public
  MODULE_DATA_PROVIDERS_TYPE         = 'Puppet::Plugins::DataProviders::ModuleDataProvider'

  # The lookup **key** for the multibind containing map of provider name to path based data provider factory
  # implementation.
  # @api public
  PATH_BASED_DATA_PROVIDER_FACTORIES_KEY  = 'puppet::path_based_data_provider_factories'

  # The lookup **type** for the multibind containing map of provider name to path based data provider factory
  # implementation.
  # @api public
  PATH_BASED_DATA_PROVIDER_FACTORIES_TYPE = 'Puppet::Plugins::DataProviders::PathBasedDataProviderFactory'

end

require_relative 'data_providers/data_provider'
require_relative 'data_providers/registry'
