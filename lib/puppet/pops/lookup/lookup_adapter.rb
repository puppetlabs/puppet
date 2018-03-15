require_relative 'data_adapter'
require_relative 'lookup_key'

module Puppet::Pops
module Lookup
# A LookupAdapter is a specialized DataAdapter that uses its hash to store data providers. It also remembers the compiler
# that it is attached to and maintains a cache of _lookup options_ retrieved from the data providers associated with the
# compiler's environment.
#
# @api private
class LookupAdapter < DataAdapter

  LOOKUP_OPTIONS_PREFIX = LOOKUP_OPTIONS + '.'
  LOOKUP_OPTIONS_PREFIX.freeze
  LOOKUP_OPTIONS_PATTERN_START = '^'.freeze

  HASH = 'hash'.freeze
  MERGE = 'merge'.freeze
  CONVERT_TO = 'convert_to'.freeze
  NEW = 'new'.freeze

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
  # @param lookup_invocation [Invocation] the lookup invocation
  # @param merge [MergeStrategy,String,Hash{String => Object},nil] Merge strategy, merge strategy name, strategy and options hash, or nil (implies "first found")
  # @return [Object] the found object
  # @throw :no_such_key when the object is not found
  #
  def lookup(key, lookup_invocation, merge)
    # The 'lookup_options' key is reserved and not found as normal data
    if key == LOOKUP_OPTIONS || key.start_with?(LOOKUP_OPTIONS_PREFIX)
      lookup_invocation.with(:invalid_key, LOOKUP_OPTIONS) do
        throw :no_such_key
      end
    end

    key = LookupKey.new(key)
    lookup_invocation.lookup(key, key.module_name) do
      if lookup_invocation.only_explain_options?
        catch(:no_such_key) { do_lookup(LookupKey::LOOKUP_OPTIONS, lookup_invocation, HASH) }
        nil
      else
        lookup_options = lookup_lookup_options(key, lookup_invocation) || {}

        if merge.nil?
          # Used cached lookup_options
          # merge = lookup_merge_options(key, lookup_invocation)
          merge = lookup_options[MERGE]
          lookup_invocation.report_merge_source(LOOKUP_OPTIONS) unless merge.nil?
        end
        convert_result(key.to_s, lookup_options, lookup_invocation, lambda do
          lookup_invocation.with(:data, key.to_s) do
            catch(:no_such_key) { return do_lookup(key, lookup_invocation, merge) }
            throw :no_such_key if lookup_invocation.global_only?
            key.dig(lookup_invocation, lookup_default_in_module(key, lookup_invocation))
          end
        end)
      end
    end
  end

  # Performs a possible conversion of the result of calling `the_lookup` lambda
  # The conversion takes place if there is a 'convert_to' key in the lookup_options
  # If there is no conversion, the result of calling `the_lookup` is returned
  # otherwise the successfully converted value.
  # Errors are raised if the convert_to is faulty (bad type string, or if a call to
  # new(T, <args>) fails.
  #
  # @param key [String] The key to lookup
  # @param lookup_options [Hash] a hash of options
  # @param lookup_invocation [Invocation] the lookup invocation
  # @param the_lookup [Lambda] zero arg lambda that performs the lookup of a value
  # @return [Object] the looked up value, or converted value if there was conversion
  # @throw :no_such_key when the object is not found (if thrown by `the_lookup`)
  #
  def convert_result(key, lookup_options, lookup_invocation, the_lookup)
    result = the_lookup.call
    convert_to = lookup_options[CONVERT_TO]
    return result if convert_to.nil?

    convert_to = convert_to.is_a?(Array) ? convert_to : [convert_to]
    if convert_to[0].is_a?(String)
      begin
        convert_to[0] = Puppet::Pops::Types::TypeParser.singleton.parse(convert_to[0])
      rescue StandardError => e
        raise Puppet::DataBinding::LookupError,
          _("Invalid data type in lookup_options for key '%{key}' could not parse '%{source}', error: '%{msg}") %
            { key: key, source: convert_to[0], msg: e.message}
      end
    end
    begin
      result = lookup_invocation.scope.call_function(NEW, [convert_to[0], result, *convert_to[1..-1]])
      # TRANSLATORS 'lookup_options', 'convert_to' and args_string variable should not be translated,
      args_string = Puppet::Pops::Types::StringConverter.singleton.convert(convert_to)
      lookup_invocation.report_text { _("Applying convert_to lookup_option with arguments %{args}") % { args: args_string } }
    rescue StandardError => e
      raise Puppet::DataBinding::LookupError,
        _("The convert_to lookup_option for key '%{key}' raised error: %{msg}") %
          { key: key, msg: e.message}
    end
    result
  end

  def lookup_global(key, lookup_invocation, merge_strategy)
    # hiera_xxx will always use global_provider regardless of data_binding_terminus setting
    terminus = lookup_invocation.hiera_xxx_call? ? :hiera : Puppet[:data_binding_terminus]
    case terminus
    when :hiera, 'hiera'
      provider = global_provider(lookup_invocation)
      throw :no_such_key if provider.nil?
      provider.key_lookup(key, lookup_invocation, merge_strategy)
    when :none, 'none', '', nil
      # If global lookup is disabled, immediately report as not found
      lookup_invocation.report_not_found(key)
      throw :no_such_key
    else
      lookup_invocation.with(:global, terminus) do
        catch(:no_such_key) do
          return lookup_invocation.report_found(key, Puppet::DataBinding.indirection.find(key.root_key,
            {:environment => environment, :variables => lookup_invocation.scope, :merge => merge_strategy}))
        end
        lookup_invocation.report_not_found(key)
        throw :no_such_key
      end
    end
  rescue Puppet::DataBinding::LookupError => detail
    raise detail unless detail.issue_code.nil?
    error = Puppet::Error.new(_("Lookup of key '%{key}' failed: %{detail}") % { key: lookup_invocation.top_key, detail: detail.message })
    error.set_backtrace(detail.backtrace)
    raise error
  end

  def lookup_in_environment(key, lookup_invocation, merge_strategy)
    provider = env_provider(lookup_invocation)
    throw :no_such_key if provider.nil?
    provider.key_lookup(key, lookup_invocation, merge_strategy)
  end

  def lookup_in_module(key, lookup_invocation, merge_strategy)
    module_name = lookup_invocation.module_name

    # Do not attempt to do a lookup in a module unless the name is qualified.
    throw :no_such_key if module_name.nil?

    provider = module_provider(lookup_invocation, module_name)
    if provider.nil?
      if environment.module(module_name).nil?
        lookup_invocation.report_module_not_found(module_name)
      else
        lookup_invocation.report_module_provider_not_found(module_name)
      end
      throw :no_such_key
    end
    provider.key_lookup(key, lookup_invocation, merge_strategy)
  end

  def lookup_default_in_module(key, lookup_invocation)
    module_name = lookup_invocation.module_name

    # Do not attempt to do a lookup in a module unless the name is qualified.
    throw :no_such_key if module_name.nil?

    provider = module_provider(lookup_invocation, module_name)
    throw :no_such_key if provider.nil? || !provider.config(lookup_invocation).has_default_hierarchy?

    lookup_invocation.with(:scope, "Searching default_hierarchy of module \"#{module_name}\"") do
      merge_strategy = nil
      if merge_strategy.nil?
        @module_default_lookup_options ||= {}
        options = @module_default_lookup_options.fetch(module_name) do |k|
          meta_invocation = Invocation.new(lookup_invocation.scope)
          meta_invocation.lookup(LookupKey::LOOKUP_OPTIONS, k) do
            opts = nil
            lookup_invocation.with(:scope, "Searching for \"#{LookupKey::LOOKUP_OPTIONS}\"") do
              catch(:no_such_key) do
              opts = compile_patterns(
                validate_lookup_options(
                  provider.key_lookup_in_default(LookupKey::LOOKUP_OPTIONS, meta_invocation, MergeStrategy.strategy(HASH)), k))
              end
            end
            @module_default_lookup_options[k] = opts
          end
        end
        lookup_options = extract_lookup_options_for_key(key, options)
        merge_strategy = lookup_options[MERGE] unless lookup_options.nil?
      end

      lookup_invocation.with(:scope, "Searching for \"#{key}\"") do
        provider.key_lookup_in_default(key, lookup_invocation, merge_strategy)
      end
    end
  end

  # Retrieve the merge options that match the given `name`.
  #
  # @param key [LookupKey] The key for which we want merge options
  # @param lookup_invocation [Invocation] the lookup invocation
  # @return [String,Hash,nil] The found merge options or nil
  #
  def lookup_merge_options(key, lookup_invocation)
    lookup_options = lookup_lookup_options(key, lookup_invocation)
    lookup_options.nil? ? nil : lookup_options[MERGE]
  end

  # Retrieve the lookup options that match the given `name`.
  #
  # @param key [LookupKey] The key for which we want lookup options
  # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] the lookup invocation
  # @return [String,Hash,nil] The found lookup options or nil
  #
  def lookup_lookup_options(key, lookup_invocation)
    module_name = key.module_name

    # Retrieve the options for the module. We use nil as a key in case we have no module
    if !@lookup_options.include?(module_name)
      options = retrieve_lookup_options(module_name, lookup_invocation, MergeStrategy.strategy(HASH))
      @lookup_options[module_name] = options
    else
      options = @lookup_options[module_name]
    end
    extract_lookup_options_for_key(key, options)
  end

  def extract_lookup_options_for_key(key, options)
    return nil if options.nil?

    rk = key.root_key
    key_opts = options[0]
    unless key_opts.nil?
      key_opt = key_opts[rk]
      return key_opt unless key_opt.nil?
    end

    patterns = options[1]
    patterns.each_pair { |pattern, value| return value if pattern =~ rk } unless patterns.nil?
    nil
  end

  # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] the lookup invocation
  # @return [Boolean] `true` if an environment data provider version 5 is configured
  def has_environment_data_provider?(lookup_invocation)
    ep = env_provider(lookup_invocation)
    ep.nil? ? false : ep.config(lookup_invocation).version >= 5
  end

  # @return [Pathname] the full path of the hiera.yaml config file
  def global_hiera_config_path
    @global_hiera_config_path ||= Pathname.new(Puppet.settings[:hiera_config])
  end

  # @param path [String] the absolute path name of the global hiera.yaml file.
  # @return [LookupAdapter] self
  def set_global_hiera_config_path(path)
    @global_hiera_config_path = Pathname.new(path)
    self
  end

  def global_only?
    instance_variable_defined?(:@global_only) ? @global_only : false
  end

  # Instructs the lookup framework to only perform lookups in the global layer
  # @return [LookupAdapter] self
  def set_global_only
    @global_only = true
    self
  end

  private

  PROVIDER_STACK = [:lookup_global, :lookup_in_environment, :lookup_in_module].freeze

  def validate_lookup_options(options, module_name)
    raise Puppet::DataBinding::LookupError.new(_("value of %{opts} must be a hash") % { opts: LOOKUP_OPTIONS }) unless options.is_a?(Hash) unless options.nil?
    return options if module_name.nil?

    pfx = "#{module_name}::"
    options.each_pair do |key, value|
      if key.start_with?(LOOKUP_OPTIONS_PATTERN_START)
        unless key[1..pfx.length] == pfx
          raise Puppet::DataBinding::LookupError.new(_("all %{opts} patterns must match a key starting with module name '%{module_name}'") % { opts: LOOKUP_OPTIONS, module_name: module_name })
        end
      else
        unless key.start_with?(pfx)
          raise Puppet::DataBinding::LookupError.new(_("all %{opts} keys must start with module name '%{module_name}'") % { opts: LOOKUP_OPTIONS, module_name: module_name })
        end
      end
    end
  end

  def compile_patterns(options)
    return nil if options.nil?
    key_options = {}
    pattern_options = {}
    options.each_pair do |key, value|
      if key.start_with?(LOOKUP_OPTIONS_PATTERN_START)
        pattern_options[Regexp.compile(key)] = value
      else
        key_options[key] = value
      end
    end
    [key_options.empty? ? nil : key_options, pattern_options.empty? ? nil : pattern_options]
  end

  def do_lookup(key, lookup_invocation, merge)
    if lookup_invocation.global_only?
      key.dig(lookup_invocation, lookup_global(key, lookup_invocation, merge))
    else
      merge_strategy = Puppet::Pops::MergeStrategy.strategy(merge)
      key.dig(lookup_invocation,
        merge_strategy.lookup(PROVIDER_STACK, lookup_invocation) { |m| send(m, key, lookup_invocation, merge_strategy) })
    end
  end

  GLOBAL_ENV_MERGE = 'Global and Environment'.freeze

  # Retrieve lookup options that applies when using a specific module (i.e. a merge of the pre-cached
  # `env_lookup_options` and the module specific data)
  def retrieve_lookup_options(module_name, lookup_invocation, merge_strategy)
    meta_invocation = Invocation.new(lookup_invocation.scope)
    meta_invocation.lookup(LookupKey::LOOKUP_OPTIONS, lookup_invocation.module_name) do
      meta_invocation.with(:meta, LOOKUP_OPTIONS) do
        if meta_invocation.global_only?
          compile_patterns(global_lookup_options(meta_invocation, merge_strategy))
        else
          opts = env_lookup_options(meta_invocation, merge_strategy)
          unless module_name.nil?
            # Store environment options at key nil. This removes the need for an additional lookup for keys that are not prefixed.
            @lookup_options[nil] = compile_patterns(opts) unless @lookup_options.include?(nil)
            catch(:no_such_key) do
              module_opts = validate_lookup_options(lookup_in_module(LookupKey::LOOKUP_OPTIONS, meta_invocation, merge_strategy), module_name)
              opts = if opts.nil?
                module_opts
              else
                merge_strategy.lookup([GLOBAL_ENV_MERGE, "Module #{lookup_invocation.module_name}"], meta_invocation) do |n|
                  meta_invocation.with(:scope, n) { meta_invocation.report_found(LOOKUP_OPTIONS,  n == GLOBAL_ENV_MERGE ? opts : module_opts) }
                end
              end
            end
          end
          compile_patterns(opts)
        end
      end
    end
  end

  # Retrieve and cache the global lookup options
  def global_lookup_options(lookup_invocation, merge_strategy)
    if !instance_variable_defined?(:@global_lookup_options)
      @global_lookup_options = nil
      catch(:no_such_key) { @global_lookup_options = validate_lookup_options(lookup_global(LookupKey::LOOKUP_OPTIONS, lookup_invocation, merge_strategy), nil) }
    end
    @global_lookup_options
  end

  # Retrieve and cache lookup options specific to the environment of the compiler that this adapter is attached to (i.e. a merge
  # of global and environment lookup options).
  def env_lookup_options(lookup_invocation, merge_strategy)
    if !instance_variable_defined?(:@env_lookup_options)
      global_options = global_lookup_options(lookup_invocation, merge_strategy)
      @env_only_lookup_options = nil
      catch(:no_such_key) { @env_only_lookup_options = validate_lookup_options(lookup_in_environment(LookupKey::LOOKUP_OPTIONS, lookup_invocation, merge_strategy), nil) }
      if global_options.nil?
        @env_lookup_options = @env_only_lookup_options
      elsif @env_only_lookup_options.nil?
        @env_lookup_options = global_options
      else
        @env_lookup_options = merge_strategy.merge(global_options, @env_only_lookup_options)
      end
    end
    @env_lookup_options
  end

  def global_provider(lookup_invocation)
    @global_provider = GlobalDataProvider.new unless instance_variable_defined?(:@global_provider)
    @global_provider
  end

  def env_provider(lookup_invocation)
    @env_provider = initialize_env_provider(lookup_invocation) unless instance_variable_defined?(:@env_provider)
    @env_provider
  end

  def module_provider(lookup_invocation, module_name)
    # Test if the key is present for the given module_name. It might be there even if the
    # value is nil (which indicates that no module provider is configured for the given name)
    unless self.include?(module_name)
      self[module_name] = initialize_module_provider(lookup_invocation, module_name)
    end
    self[module_name]
  end

  def initialize_module_provider(lookup_invocation, module_name)
    mod = environment.module(module_name)
    return nil if mod.nil?

    metadata = mod.metadata
    provider_name = metadata.nil? ? nil : metadata['data_provider']

    mp = nil
    if mod.has_hiera_conf?
      mp = ModuleDataProvider.new(module_name)
      # A version 5 hiera.yaml trumps a data provider setting in the module
      mp_config = mp.config(lookup_invocation)
      if mp_config.nil?
        mp = nil
      elsif mp_config.version >= 5
        unless provider_name.nil? || Puppet[:strict] == :off
          Puppet.warn_once('deprecations', "metadata.json#data_provider-#{module_name}",
            _("Defining \"data_provider\": \"%{name}\" in metadata.json is deprecated. It is ignored since a '%{config}' with version >= 5 is present") % { name: provider_name, config: HieraConfig::CONFIG_FILE_NAME }, mod.metadata_file)
        end
        provider_name = nil
      end
    end

    if provider_name.nil?
      mp
    else
      unless Puppet[:strict] == :off
        msg = _("Defining \"data_provider\": \"%{name}\" in metadata.json is deprecated.") % { name: provider_name }
        msg += " " + _("A '%{hiera_config}' file should be used instead") % { hiera_config: HieraConfig::CONFIG_FILE_NAME } if mp.nil?
        Puppet.warn_once('deprecations', "metadata.json#data_provider-#{module_name}", msg, mod.metadata_file)
      end

      case provider_name
      when 'none'
        nil
      when 'hiera'
        mp || ModuleDataProvider.new(module_name)
      when 'function'
        mp = ModuleDataProvider.new(module_name)
        mp.config = HieraConfig.v4_function_config(Pathname(mod.path), "#{module_name}::data", mp)
        mp
      else
        raise Puppet::Error.new(_("Environment '%{env}', cannot find module_data_provider '%{provider}'")) % { env: environment.name, provider: provider_name }
      end
    end
  end

  def initialize_env_provider(lookup_invocation)
    env_conf = environment.configuration
    return nil if env_conf.nil? || env_conf.path_to_env.nil?

    # Get the name of the data provider from the environment's configuration
    provider_name = env_conf.environment_data_provider
    env_path = Pathname(env_conf.path_to_env)
    config_path = env_path + HieraConfig::CONFIG_FILE_NAME

    ep = nil
    if config_path.exist?
      ep = EnvironmentDataProvider.new
      # A version 5 hiera.yaml trumps any data provider setting in the environment.conf
      ep_config = ep.config(lookup_invocation)
      if ep_config.nil?
        ep = nil
      elsif ep_config.version >= 5
        unless provider_name.nil? || Puppet[:strict] == :off
          Puppet.warn_once('deprecations', 'environment.conf#data_provider',
            _("Defining environment_data_provider='%{provider_name}' in environment.conf is deprecated") % { provider_name: provider_name }, env_path + 'environment.conf')

          unless provider_name == 'hiera'
            Puppet.warn_once('deprecations', 'environment.conf#data_provider_overridden',
              _("The environment_data_provider='%{provider_name}' setting is ignored since '%{config_path}' version >= 5") % { provider_name: provider_name, config_path: config_path }, env_path + 'environment.conf')
          end
        end
        provider_name = nil
      end
    end

    if provider_name.nil?
      ep
    else
      unless Puppet[:strict] == :off
        msg = _("Defining environment_data_provider='%{provider_name}' in environment.conf is deprecated.") % { provider_name: provider_name }
        msg += " " + _("A '%{hiera_config}' file should be used instead") % { hiera_config: HieraConfig::CONFIG_FILE_NAME } if ep.nil?
        Puppet.warn_once('deprecations', 'environment.conf#data_provider', msg, env_path + 'environment.conf')
      end

      case provider_name
      when 'none'
        nil
      when 'hiera'
        # Use hiera.yaml or default settings if it is missing
        ep || EnvironmentDataProvider.new
      when 'function'
        ep = EnvironmentDataProvider.new
        ep.config = HieraConfigV5.v4_function_config(env_path, 'environment::data', ep)
        ep
      else
        raise Puppet::Error.new(_("Environment '%{env}', cannot find environment_data_provider '%{provider}'") % { env: environment.name, provider: provider_name })
      end
    end
  end

  # @return [Puppet::Node::Environment] the environment of the compiler that this adapter is associated with
  def environment
    @compiler.environment
  end
end
end
end

require_relative 'invocation'
require_relative 'global_data_provider'
require_relative 'environment_data_provider'
require_relative 'module_data_provider'
