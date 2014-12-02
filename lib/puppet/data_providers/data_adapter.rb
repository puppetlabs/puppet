# A DataAdapter adapts an object with a Hash of data
#
class Puppet::DataProviders::DataAdapter < Puppet::Pops::Adaptable::Adapter
  attr_accessor :data
  attr_accessor :env_provider

  def initialize(env)
    @env = env
    @data = {}
  end

  def [](name)
    @data[name]
  end

  def has_name?(name)
    @data.has_key?
  end

  def []=(name, value)
    unless value.is_a?(Hash)
      raise ArgumentError, "Given value must be a Hash, got: #{value.class}."
    end
    @data[name] = value
  end

  def env_provider
    @env_provider ||= initialize_env_provider
  end

  def module_provider(module_name)
    @data[module_name] ||= initialize_module_provider(module_name)
  end

  def self.create_adapter(environment)
    new(environment)
  end

  def initialize_module_provider(module_name)
    # Support running tests without an injector being configured == using a null implementation
    unless injector = Puppet.lookup(:injector) { nil }
      return Puppet::Plugins::DataProviders::ModuleDataProvider.new()
    end
    # Get the registry of module to provider implementation name
    module_service_type = Puppet::Plugins::DataProviders.hash_of_per_module_data_provider
    module_service_name = Puppet::Plugins::DataProviders::PER_MODULE_DATA_PROVIDER_KEY
    module_service = Puppet.lookup(:injector).lookup(nil, module_service_type, module_service_name)
    provider_name = module_service[module_name] || 'none'

    service_type = Puppet::Plugins::DataProviders.hash_of_module_data_providers
    service_name = Puppet::Plugins::DataProviders::MODULE_DATA_PROVIDERS_KEY

    # Get the service (registry of known implementations)
    service = Puppet.lookup(:injector).lookup(nil, service_type, service_name)
    provider = service[provider_name]
    unless provider
      raise Puppet::Error.new("Environment '#{@env.name}', cannot find module_data_provider '#{provider_name}'")
    end
    provider
  end

  def initialize_env_provider
    # Get the environment's configuration since we need to know which data provider
    # should be used (includes 'none' which gets a null implementation).
    #
    env_conf = Puppet.lookup(:environments).get_conf(@env.name)

    # Get the data provider and find the bound implementation
    # TODO: PUP-1640, drop the nil check when legacy env support is dropped
    provider_name = env_conf.nil? ? 'none' : env_conf.environment_data_provider
    service_type = Puppet::Plugins::DataProviders.hash_of_environment_data_providers
    service_name = Puppet::Plugins::DataProviders::ENV_DATA_PROVIDERS_KEY

    # Get the service (registry of known implementations)
    # Support running tests without an injector being configured == using a null implementation
    unless injector = Puppet.lookup(:injector) { nil }
      return Puppet::Plugins::DataProviders::EnvironmentDataProvider.new()
    end
    service = Puppet.lookup(:injector).lookup(nil, service_type, service_name)
    provider = service[provider_name]
    unless provider
      raise Puppet::Error.new("Environment '#{@env.name}', cannot find environment_data_provider '#{provider_name}'")
    end
    provider
  end
end
