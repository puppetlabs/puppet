class Puppet::Plugins::DataProviders
  # The lookup **key** for the multibind containing data provider name per module
  # @api public
  PER_MODULE_DATA_PROVIDER_KEY       = 'puppet::module_data'

  # The lookup **type** for the name of the per module data provider.
  # @api public
  PER_MODULE_DATA_PROVIDER_TYPE      = Puppet::Pops::Types::TypeFactory.string()

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

  def self.register_extensions(extensions)
    extensions.multibind(PER_MODULE_DATA_PROVIDER_KEY).name(PER_MODULE_DATA_PROVIDER_KEY).hash_of(PER_MODULE_DATA_PROVIDER_TYPE)
    extensions.multibind(ENV_DATA_PROVIDERS_KEY).name(ENV_DATA_PROVIDERS_KEY).hash_of(ENV_DATA_PROVIDERS_TYPE)
    extensions.multibind(MODULE_DATA_PROVIDERS_KEY).name(MODULE_DATA_PROVIDERS_KEY).hash_of(MODULE_DATA_PROVIDERS_TYPE)
  end

  # Registers a 'none' environment data provider, and a 'none' module data provider as the defaults.
  # This is only done to allow that something binds to 'none' rather than removing the entire binding (which
  # has the same effect).
  #
  def self.register_defaults(default_bindings)
    default_bindings.bind do
      name('none')
      instance_of(string())
      in_multibind(ENV_DATA_PROVIDERS_KEY)
      to_instance('Puppet::Plugins::DataProviders::EnvironmentDataProvider')
    end

    default_bindings.bind do
      name('none')
      instance_of(string())
      in_multibind(MODULE_DATA_PROVIDERS_KEY)
      to_instance('Puppet::Plugins::DataProviders::ModuleDataProvider')
    end
  end

  class ModuleDataProvider
    def lookup(name, scope)
      nil
    end
  end

  class EnvironmentDataProvider
    def lookup(name, scope)
      nil
    end
  end
end