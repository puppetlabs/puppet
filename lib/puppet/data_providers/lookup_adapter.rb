# A LookupAdapter is a specialized DataAdapter that uses its hash to store module providers. It also remembers the compiler
# that it is attached to and maintains a cache of _lookup options_ retrieved from the data providers associated with the
# compiler's environment.
#
# @api private
class Puppet::DataProviders::LookupAdapter < Puppet::DataProviders::DataAdapter

  LOOKUP_OPTIONS = Puppet::Pops::Lookup::LOOKUP_OPTIONS
  LOOKUP_OPTIONS_PREFIX = LOOKUP_OPTIONS + '.'
  LOOKUP_OPTIONS_PREFIX.freeze
  HASH = 'hash'.freeze
  MERGE = 'merge'.freeze

  def self.create_adapter(compiler)
    new(compiler)
  end

  def initialize(compiler)
    super()
    @compiler = compiler
    @lookup_options = {}
  end

  # Performs a lookup using global, environment, and module data providers. Merge the result using the given
  # _merge_ strategy. If the merge strategy is nil, then an attempt is made to find merge options in the
  # `lookup_options` hash for an entry associated with the key. If no options are found, the no merge is performed
  # and the first found entry is returned.
  #
  # @param key [String] The key to lookup
  # @param merge [Puppet::Pops::MergeStrategy,String,Hash<String,Object>,nil] Merge strategy or hash with strategy and options
  # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] Invocation data containing scope, overrides, and defaults
  # @return [Object] The found value
  # @throws :no_such_key if the given key is not found
  #
  def lookup(key, lookup_invocation, merge)
    # The 'lookup_options' key is reserved and not found as normal data
    if key == LOOKUP_OPTIONS || key.start_with?(LOOKUP_OPTIONS_PREFIX)
      lookup_invocation.with(:invalid_key, LOOKUP_OPTIONS) do
        throw :no_such_key
      end
    end

    lookup_invocation.top_key ||= key
    merge_explained = false
    if lookup_invocation.explain_options?
      catch(:no_such_key) do
        module_name = extract_module_name(key) unless key == Puppet::Pops::Lookup::GLOBAL
        lookup_invocation.module_name = module_name
        if lookup_invocation.only_explain_options?
          do_lookup(LOOKUP_OPTIONS, lookup_invocation, HASH)
          return nil
        end

        # Bypass cache and do a "normal" lookup of the lookup_options
        lookup_invocation.with(:meta, LOOKUP_OPTIONS) do
          key_options = do_lookup(LOOKUP_OPTIONS, lookup_invocation, HASH)[key]
          merge = key_options[MERGE] unless key_options.nil?
          merge_explained = true
        end
      end
    elsif merge.nil?
      # Used cached lookup_options
      merge = lookup_merge_options(key, lookup_invocation)
      lookup_invocation.report_merge_source('lookup_options') unless merge.nil?
    end

    if merge_explained
      # Merge lookup is explained in detail so we need to explain the data in a section
      # on the same level to avoid confusion
      lookup_invocation.with(:data, key) { do_lookup(key, lookup_invocation, merge) }
    else
      do_lookup(key, lookup_invocation, merge)
    end
  end

  # @api private
  def lookup_global(name, lookup_invocation, merge_strategy)
    terminus = Puppet[:data_binding_terminus]
    lookup_invocation.with(:global, terminus) do
      catch(:no_such_key) do
        return lookup_invocation.report_found(name, Puppet::DataBinding.indirection.find(name,
            { :environment => environment, :variables => lookup_invocation.scope, :merge => merge_strategy }))
      end
      lookup_invocation.report_not_found(name)
      throw :no_such_key
    end
  rescue Puppet::DataBinding::LookupError => detail
    error = Puppet::Error.new("Lookup of key '#{lookup_invocation.top_key}' failed: #{detail.message}")
    error.set_backtrace(detail.backtrace)
    raise error
  end

  # @api private
  def lookup_in_environment(name, lookup_invocation, merge_strategy)
    env_provider.lookup(name, lookup_invocation, merge_strategy)
  end

  # @api private
  def lookup_in_module(name, lookup_invocation, merge_strategy)
    module_name = lookup_invocation.module_name || extract_module_name(name)

    # Do not attempt to do a lookup in a module unless the name is qualified.
    throw :no_such_key if module_name.nil?

    lookup_invocation.with(:module, module_name) do
      if environment.module(module_name).nil?
        lookup_invocation.report_module_not_found
        throw :no_such_key
      end
      module_provider(module_name).lookup(name, lookup_invocation, merge_strategy)
    end
  end

  # Retrieve the merge options that match the given `name`.
  #
  # @param name [String] The key for which we want merge options
  # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] the lookup invocation
  # @return [String,Hash,nil] The found merge options or nil
  #
  def lookup_merge_options(name, lookup_invocation)
    lookup_options = lookup_lookup_options(name, lookup_invocation)
    lookup_options.nil? ? nil : lookup_options[MERGE]
  end

  # Retrieve the lookup options that match the given `name`.
  #
  # @param name [String] The key for which we want lookup options
  # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] the lookup invocation
  # @return [String,Hash,nil] The found lookup options or nil
  #
  def lookup_lookup_options(name, lookup_invocation)
    module_name = extract_module_name(name)

    # Retrieve the options for the module. We use nil as a key in case we have none
    if !@lookup_options.include?(module_name)
      options = retrieve_lookup_options(module_name, lookup_invocation, Puppet::Pops::MergeStrategy.strategy(HASH))
      raise Puppet::DataBinding::LookupError.new("value of #{LOOKUP_OPTIONS} must be a hash") unless options.nil? || options.is_a?(Hash)
      @lookup_options[module_name] = options
    else
      options = @lookup_options[module_name]
    end
    options.nil? ? nil : options[name]
  end

  private

  def do_lookup(key, lookup_invocation, merge)
    merge_strategy = Puppet::Pops::MergeStrategy.strategy(merge)
    lookup_invocation.with(:merge, merge_strategy) do
      result = merge_strategy.merge_lookup([:lookup_global, :lookup_in_environment, :lookup_in_module]) { |m| send(m, key, lookup_invocation, merge_strategy) }
      lookup_invocation.report_result(result)
      result
    end
  end

  # Retrieve lookup options that applies when using a specific module (i.e. a merge of the pre-cached
  # `env_lookup_options` and the module specific data)
  def retrieve_lookup_options(module_name, lookup_invocation, merge_strategy)
    meta_invocation = Puppet::Pops::Lookup::Invocation.new(lookup_invocation.scope)
    meta_invocation.top_key = lookup_invocation.top_key
    env_opts = env_lookup_options(meta_invocation, merge_strategy)
    unless module_name.nil? || environment.module(module_name).nil?
      catch(:no_such_key) do
        meta_invocation.module_name = module_name
        options = module_provider(module_name).lookup(LOOKUP_OPTIONS, meta_invocation, merge_strategy)
        options = merge_strategy.merge(env_opts, options) unless env_opts.nil?
        return options
      end
    end
    env_opts
  end

  # Retrieve and cache lookup options specific to the environment of the compiler that this adapter is attached to (i.e. a merge
  # of global and environment lookup options).
  def env_lookup_options(meta_invocation, merge_strategy)
    if !instance_variable_defined?(:@env_lookup_options)
      @env_lookup_options = nil
      catch(:no_such_key) do
        @env_lookup_options = merge_strategy.merge_lookup([:lookup_global, :lookup_in_environment]) do |m|
          send(m, LOOKUP_OPTIONS, meta_invocation, merge_strategy)
        end
      end
    end
    @env_lookup_options
  end

  def env_provider
    @env_provider ||= initialize_env_provider
  end

  def module_provider(module_name)
    # Test if the key is present for the given module_name. It might be there even if the
    # value is nil (which indicates that no module provider is configured for the given name)
    unless data.include?(module_name)
      data[module_name] = initialize_module_provider(module_name)
    end
    data[module_name]
  end

  def initialize_module_provider(module_name)
    injector = Puppet.lookup(:injector) { nil }

    # Support running tests without an injector being configured == using a null implementation
    return ModuleDataProvider.new() unless injector

    # Get the registry of module to provider implementation name
    module_service_type = Registry.hash_of_per_module_data_provider
    module_service_name = PER_MODULE_DATA_PROVIDER_KEY
    module_service = injector.lookup(nil, module_service_type, module_service_name)
    provider_name = module_service[module_name] || 'none'

    service_type = Registry.hash_of_module_data_providers
    service_name = MODULE_DATA_PROVIDERS_KEY

    # Get the service (registry of known implementations)
    service = injector.lookup(nil, service_type, service_name)
    provider = service[provider_name]
    unless provider
      raise Puppet::Error.new("Environment '#{environment.name}', cannot find module_data_provider '#{provider_name}'")
    end
    # Provider is configured per module but cached using compiler life cycle so it must be cloned
    provider.clone
  end

  def initialize_env_provider
    injector = Puppet.lookup(:injector) { nil }

    # Support running tests without an injector being configured == using a null implementation
    return EnvironmentDataProvider.new() unless injector

    # Get the name of the data provider from the environment's configuration and find the bound implementation
    provider_name = environment.configuration.environment_data_provider
    service_type = Registry.hash_of_environment_data_providers
    service_name = ENV_DATA_PROVIDERS_KEY

    # Get the service (registry of known implementations)
    service = injector.lookup(nil, service_type, service_name)
    provider = service[provider_name]
    unless provider
      raise Puppet::Error.new("Environment '#{environment.name}', cannot find environment_data_provider '#{provider_name}'")
    end
    provider
  end

  def extract_module_name(name)
    qual_index = name.index('::')
    qual_index.nil? ? nil : name[0..qual_index-1]
  end

  # @return [Puppet::Node::Environment] the environment of the compiler that this adapter is associated with
  def environment
    @compiler.environment
  end
end
