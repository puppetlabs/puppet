module Puppet::Plugins::DataProviders
  class Registry
    def self.register_extensions(extensions)
      extensions.multibind(PER_MODULE_DATA_PROVIDER_KEY).name(PER_MODULE_DATA_PROVIDER_KEY).hash_of(PER_MODULE_DATA_PROVIDER_TYPE)
      extensions.multibind(ENV_DATA_PROVIDERS_KEY).name(ENV_DATA_PROVIDERS_KEY).hash_of(ENV_DATA_PROVIDERS_TYPE)
      extensions.multibind(MODULE_DATA_PROVIDERS_KEY).name(MODULE_DATA_PROVIDERS_KEY).hash_of(MODULE_DATA_PROVIDERS_TYPE)
      extensions.multibind(PATH_BASED_DATA_PROVIDER_FACTORIES_KEY).name(PATH_BASED_DATA_PROVIDER_FACTORIES_KEY).hash_of(PATH_BASED_DATA_PROVIDER_FACTORIES_TYPE)
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

    def self.hash_of_path_based_data_provider_factories
      @@HASH_OF_PATH_BASED_DATA_PROVIDER_FACTORIES ||= Puppet::Pops::Types::TypeFactory.hash_of(
        Puppet::Pops::Types::TypeFactory.type_of(PATH_BASED_DATA_PROVIDER_FACTORIES_TYPE))
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
        name('hiera')
        in_multibind(ENV_DATA_PROVIDERS_KEY)
        to_instance('Puppet::DataProviders::HieraEnvDataProvider')
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

      default_bindings.bind do
        name('hiera')
        in_multibind(MODULE_DATA_PROVIDERS_KEY)
        to_instance('Puppet::DataProviders::HieraModuleDataProvider')
      end

      default_bindings.bind do
        name('hocon')
        in_multibind(PATH_BASED_DATA_PROVIDER_FACTORIES_KEY)
        to_instance('Puppet::DataProviders::HoconDataProviderFactory')
      end

      default_bindings.bind do
        name('json')
        in_multibind(PATH_BASED_DATA_PROVIDER_FACTORIES_KEY)
        to_instance('Puppet::DataProviders::JsonDataProviderFactory')
      end

      default_bindings.bind do
        name('yaml')
        in_multibind(PATH_BASED_DATA_PROVIDER_FACTORIES_KEY)
        to_instance('Puppet::DataProviders::YamlDataProviderFactory')
      end
    end
  end
end

