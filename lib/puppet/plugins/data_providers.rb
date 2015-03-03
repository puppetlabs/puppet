module Puppet::Plugins; end

class Puppet::Plugins::DataProviders

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

  def self.register_extensions(extensions)
    extensions.multibind(PER_MODULE_DATA_PROVIDER_KEY).name(PER_MODULE_DATA_PROVIDER_KEY).hash_of(PER_MODULE_DATA_PROVIDER_TYPE)
    extensions.multibind(ENV_DATA_PROVIDERS_KEY).name(ENV_DATA_PROVIDERS_KEY).hash_of(ENV_DATA_PROVIDERS_TYPE)
    extensions.multibind(MODULE_DATA_PROVIDERS_KEY).name(MODULE_DATA_PROVIDERS_KEY).hash_of(MODULE_DATA_PROVIDERS_TYPE)
  end

  def self.hash_of_per_module_data_provider
    @@HASH_OF_PER_MODULE_DATA_PROVIDERS ||= Puppet::Pops::Types::TypeFactory.hash_of(PER_MODULE_DATA_PROVIDER_TYPE)
  end

  def self.hash_of_module_data_providers
    @@HASH_OF_MODULE_DATA_PROVIDERS ||= Puppet::Pops::Types::TypeFactory.hash_of(
      Puppet::Pops::Types::TypeFactory.type_of(MODULE_DATA_PROVIDERS_TYPE))
  end

  def self.hash_of_environment_data_providers
    @@HASH_OF_ENV_DATA_PROVIDERS ||= Puppet::Pops::Types::TypeFactory.hash_of(
      Puppet::Pops::Types::TypeFactory.type_of(ENV_DATA_PROVIDERS_TYPE))
  end

  # Registers a 'none' environment data provider, and a 'none' module data provider as the defaults.
  # This is only done to allow that something binds to 'none' rather than removing the entire binding (which
  # has the same effect).
  #
  def self.register_defaults(default_bindings)
    default_bindings.bind do
      name('none')
      in_multibind(ENV_DATA_PROVIDERS_KEY)
      to_instance(ENV_DATA_PROVIDERS_TYPE)
    end

    default_bindings.bind do
      name('function')
      in_multibind(ENV_DATA_PROVIDERS_KEY)
      to_instance('Puppet::DataProviders::FunctionEnvDataProvider')
    end

    default_bindings.bind do
      name('none')
      in_multibind(MODULE_DATA_PROVIDERS_KEY)
      to_instance(MODULE_DATA_PROVIDERS_TYPE)
    end

    default_bindings.bind do
      name('function')
      in_multibind(MODULE_DATA_PROVIDERS_KEY)
      to_instance('Puppet::DataProviders::FunctionModuleDataProvider')
    end
  end

  class ModuleDataProvider
    def lookup(name, scope, merge)
      throw :no_such_key
    end
  end

  class EnvironmentDataProvider
    def lookup(name, scope, merge)
      throw :no_such_key
    end
  end
end
