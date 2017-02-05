require_relative 'data_dig_function_provider'
require_relative 'data_hash_function_provider'
require_relative 'lookup_key_function_provider'
require_relative 'location_resolver'

module Puppet::Pops
module Lookup

# @api private
class ScopeLookupCollectingInvocation < Invocation
  attr_reader :scope_interpolations

  def initialize(scope)
    super(scope)
    @scope_interpolations = []
  end

  def remember_scope_lookup(*lookup_result)
    @scope_interpolations << lookup_result
  end
end

# @api private
class HieraConfig
  include LocationResolver
  include LabelProvider

  CONFIG_FILE_NAME = 'hiera.yaml'

  KEY_NAME = 'name'.freeze
  KEY_VERSION = 'version'.freeze
  KEY_DATADIR = 'datadir'.freeze
  KEY_HIERARCHY = 'hierarchy'.freeze
  KEY_LOGGER = 'logger'.freeze
  KEY_OPTIONS = 'options'.freeze
  KEY_PATH = 'path'.freeze
  KEY_PATHS = 'paths'.freeze
  KEY_GLOB = 'glob'.freeze
  KEY_GLOBS = 'globs'.freeze
  KEY_URI = 'uri'.freeze
  KEY_URIS = 'uris'.freeze
  KEY_DEFAULTS = 'defaults'.freeze
  KEY_DATA_HASH = DataHashFunctionProvider::TAG
  KEY_LOOKUP_KEY = LookupKeyFunctionProvider::TAG
  KEY_DATA_DIG = DataDigFunctionProvider::TAG
  KEY_V3_DATA_HASH = V3DataHashFunctionProvider::TAG
  KEY_V3_LOOKUP_KEY = V3LookupKeyFunctionProvider::TAG
  KEY_V3_BACKEND = V3BackendFunctionProvider::TAG
  KEY_V4_DATA_HASH = V4DataHashFunctionProvider::TAG
  KEY_BACKEND = 'backend'.freeze

  FUNCTION_KEYS = [KEY_DATA_HASH, KEY_LOOKUP_KEY, KEY_DATA_DIG, KEY_V3_BACKEND]
  ALL_FUNCTION_KEYS = FUNCTION_KEYS + [KEY_V4_DATA_HASH]
  LOCATION_KEYS = [KEY_PATH, KEY_PATHS, KEY_GLOB, KEY_GLOBS, KEY_URI, KEY_URIS]
  FUNCTION_PROVIDERS = {
    KEY_DATA_HASH => DataHashFunctionProvider,
    KEY_DATA_DIG => DataDigFunctionProvider,
    KEY_LOOKUP_KEY => LookupKeyFunctionProvider,
    KEY_V3_DATA_HASH => V3DataHashFunctionProvider,
    KEY_V3_BACKEND => V3BackendFunctionProvider,
    KEY_V3_LOOKUP_KEY => V3LookupKeyFunctionProvider,
    KEY_V4_DATA_HASH => V4DataHashFunctionProvider
  }

  def self.v4_function_config(config_root, function_name)
    unless Puppet[:strict] == :off
      Puppet.warn_once(:deprecation, 'legacy_provider_function',
        "Using of legacy data provider function '#{function_name}'. Please convert to a 'data_hash' function")
    end
    HieraConfigV5.new(config_root, nil,
      {
        KEY_VERSION => 5,
        KEY_HIERARCHY => [
          {
            KEY_NAME => "Legacy function '#{function_name}'",
            KEY_V4_DATA_HASH => function_name
          }
        ]
      }.freeze
    )
  end

  def self.config_exist?(config_root)
    config_path = config_root + CONFIG_FILE_NAME
    config_path.exist?
  end

  def self.symkeys_to_string(struct)
    case(struct)
    when Hash
      Hash[struct.map { |k,v| [k.to_s, symkeys_to_string(v)] }]
    when Array
      struct.map { |v| symkeys_to_string(v) }
    else
      struct
    end
  end

  # Creates a new HieraConfig from the given _config_root_. This is where the 'hiera.yaml' is expected to be found
  # and is also the base location used when resolving relative paths.
  #
  # @param config_path [Pathname] Absolute path to the configuration file
  # @return [LookupConfiguration] the configuration
  def self.create(config_path)
    if config_path.is_a?(Hash)
      config_path = nil
      loaded_config = config_path
    else
      config_root = config_path.parent
      if config_path.exist?
        loaded_config = YAML.load_file(config_path)

        # For backward compatibility, we must treat an empty file, or a yaml that doesn't
        # produce a Hash as Hiera version 3 default.
        unless loaded_config.is_a?(Hash)
          Puppet.warning("#{config_path}: File exists but does not contain a valid YAML hash. Falling back to Hiera version 3 default config")
          loaded_config = HieraConfigV3::DEFAULT_CONFIG_HASH
        end
      else
        config_path = nil
        loaded_config = HieraConfigV5::DEFAULT_CONFIG_HASH
      end
    end

    version = loaded_config[KEY_VERSION] || loaded_config[:version]
    version = version.nil? ? 3 : version.to_i
    case version
    when 5
      HieraConfigV5.new(config_root, config_path, loaded_config)
    when 4
      HieraConfigV4.new(config_root, config_path, loaded_config)
    when 3
      HieraConfigV3.new(config_root, config_path, loaded_config)
    else
      raise Puppet::DataBinding::LookupError, "#{@config_path}: This runtime does not support #{CONFIG_FILE_NAME} version '#{version}'"
    end
  end

  attr_reader :config_path, :version

  # Creates a new HieraConfig from the given _config_root_. This is where the 'lookup.yaml' is expected to be found
  # and is also the base location used when resolving relative paths.
  #
  # @param config_path [Pathname] Absolute path to the configuration
  # @param loaded_config [Hash] the loaded configuration
  def initialize(config_root, config_path, loaded_config)
    @config_root = config_root
    @config_path = config_path
    @loaded_config = loaded_config
    @config = validate_config(self.class.symkeys_to_string(@loaded_config))
    @data_providers = nil
  end

  # Returns the data providers for this config
  #
  # @param lookup_invocation [Invocation] Invocation data containing scope, overrides, and defaults
  # @param parent_data_provider [DataProvider] The data provider that loaded this configuration
  # @return [Array<DataProvider>] the data providers
  def configured_data_providers(lookup_invocation, parent_data_provider)
    unless @data_providers && scope_interpolations_stable?(lookup_invocation)
      if @data_providers
        lookup_invocation.report_text { 'Hiera configuration recreated due to change of scope variables used in interpolation expressions' }
      end
      slc_invocation = ScopeLookupCollectingInvocation.new(lookup_invocation.scope)
      @data_providers = create_configured_data_providers(slc_invocation, parent_data_provider)
      @scope_interpolations = slc_invocation.scope_interpolations
    end
    @data_providers
  end

  def scope_interpolations_stable?(lookup_invocation)
    scope = lookup_invocation.scope
    @scope_interpolations.all? do |key, root_key, segments, old_value|
      value = scope[root_key]
      unless value.nil? || segments.empty?
        found = '';
        catch(:no_such_key) { found = sub_lookup(key, lookup_invocation, segments, value) }
        value = found;
      end
      old_value.eql?(value)
    end
  end

  # @api private
  def create_configured_data_providers(lookup_invocation, parent_data_provider)
    self.class.not_implemented(self, 'create_configured_data_providers')
  end

  def validate_config(config)
    self.class.not_implemented(self, 'validate_config')
  end

  def version
    self.class.not_implemented(self, 'version')
  end

  def name
    "hiera configuration version #{version}"
  end

  def create_hiera3_backend_provider(name, backend, parent_data_provider, datadir, paths, hiera3_config)
    # Custom backend. Hiera v3 must be installed, it's logger configured, and it must be made aware of the loaded config
    require 'hiera'
    if Hiera::Config.instance_variable_defined?(:@config) && (current_config = Hiera::Config.instance_variable_get(:@config)).is_a?(Hash)
      current_config.each_pair do |key, val|
        case key
        when :hierarchy, :backends
          hiera3_config[key] = ([val] + [hiera3_config[key]]).flatten.uniq
        else
          hiera3_config[key] = val
        end
      end
    else
      if hiera3_config.include?(KEY_LOGGER)
        Hiera.logger = hiera3_config[KEY_LOGGER].to_s
      else
        Hiera.logger = 'puppet'
      end
    end

    unless Hiera::Interpolate.const_defined?(:PATCHED_BY_HIERA_5)
      # Replace the class methods 'hiera_interpolate' and 'alias_interpolate' with a method that wires back and performs global
      # lookups using the lookup framework. This is necessary since the classic Hiera is made aware only of custom backends.
      class << Hiera::Interpolate
        hiera_interpolate = Proc.new do |data, key, scope, extra_data, context|
          override = context[:order_override]
          invocation = Puppet::Pops::Lookup::Invocation.current
          unless override.nil? && invocation.global_only?
            invocation = Puppet::Pops::Lookup::Invocation.new(scope)
            invocation.set_global_only
            invocation.set_hiera_v3_location_overrides(override) unless override.nil?
          end
          Puppet::Pops::Lookup::LookupAdapter.adapt(scope.compiler).lookup(key, invocation, nil)
        end

        send(:remove_method, :hiera_interpolate)
        send(:remove_method, :alias_interpolate)
        send(:define_method, :hiera_interpolate, hiera_interpolate)
        send(:define_method, :alias_interpolate, hiera_interpolate)
      end
      Hiera::Interpolate.send(:const_set, :PATCHED_BY_HIERA_5, true)
    end

    Hiera::Config.instance_variable_set(:@config, hiera3_config)

    # Use a special lookup_key that delegates to the backend
    paths = nil if !paths.nil? && paths.empty?
    create_data_provider(name, parent_data_provider, KEY_V3_BACKEND, 'hiera_v3_data', { KEY_DATADIR => datadir, KEY_BACKEND => backend }, paths)
  end

  private

  def create_data_provider(name, parent_data_provider, function_kind, function_name, options, locations)
    FUNCTION_PROVIDERS[function_kind].new(name, parent_data_provider, function_name, options, locations)
  end

  def self.not_implemented(impl, method_name)
    raise NotImplementedError, "The class #{impl.class.name} should have implemented the method #{method_name}()"
  end
end

# @api private
class HieraConfigV3 < HieraConfig
  KEY_BACKENDS = 'backends'.freeze
  KEY_MERGE_BEHAVIOR = 'merge_behavior'.freeze
  KEY_DEEP_MERGE_OPTIONS = 'deep_merge_options'.freeze

  def self.config_type
    return @@CONFIG_TYPE if class_variable_defined?(:@@CONFIG_TYPE)
    tf = Types::TypeFactory
    nes_t = Types::PStringType::NON_EMPTY

    # This is a hash, not a type. Contained backends are added prior to validation
    @@CONFIG_TYPE = {
      tf.optional(KEY_VERSION) => tf.range(3,3),
      tf.optional(KEY_BACKENDS) => tf.variant(nes_t, tf.array_of(nes_t)),
      tf.optional(KEY_LOGGER) => nes_t,
      tf.optional(KEY_MERGE_BEHAVIOR) => tf.enum('deep', 'deeper', 'native'),
      tf.optional(KEY_DEEP_MERGE_OPTIONS) => tf.hash_kv(nes_t, tf.variant(tf.string, tf.boolean)),
      tf.optional(KEY_HIERARCHY) => tf.variant(nes_t, tf.array_of(nes_t))
    }
  end

  def create_configured_data_providers(lookup_invocation, parent_data_provider)
    scope = lookup_invocation.scope
    unless scope.is_a?(Hiera::Scope)
      lookup_invocation = Invocation.new(
        Hiera::Scope.new(scope),
        lookup_invocation.override_values,
        lookup_invocation.default_values,
        lookup_invocation.explainer)
    end

    default_datadir = File.join(Puppet.settings[:codedir], 'environments', '%{::environment}', 'hieradata')
    data_providers = {}

    [@config[KEY_BACKENDS]].flatten.each do |backend|
      raise Puppet::DataBinding::LookupError, "#{@config_path}: Backend '#{backend}' defined more than once" if data_providers.include?(backend)
      original_paths = [@config[KEY_HIERARCHY]].flatten
      backend_config = @config[backend] || EMPTY_HASH
      datadir = Pathname(interpolate(backend_config[KEY_DATADIR] || default_datadir, lookup_invocation, false))
      ext = backend == 'hocon' ? '.conf' : ".#{backend}"
      paths = resolve_paths(datadir, original_paths, lookup_invocation, @config_path.nil?, ext)
      data_providers[backend] = case
      when backend == 'json', backend == 'yaml'
        create_data_provider(backend, parent_data_provider, KEY_V3_DATA_HASH, "#{backend}_data", { KEY_DATADIR => datadir }, paths)
      when backend == 'hocon' && Puppet.features.hocon?
        create_data_provider(backend, parent_data_provider, KEY_V3_DATA_HASH, 'hocon_data', { KEY_DATADIR => datadir }, paths)
      when backend == 'eyaml' && Puppet.features.hiera_eyaml?
        create_data_provider(backend, parent_data_provider, KEY_V3_LOOKUP_KEY, 'eyaml_lookup_key', backend_config.merge(KEY_DATADIR => datadir), paths)
      else
        create_hiera3_backend_provider(backend, backend, parent_data_provider, datadir, paths, @loaded_config)
      end
    end
    data_providers.values
  end

  DEFAULT_CONFIG_HASH =  {
    KEY_BACKENDS => %w(yaml),
    KEY_HIERARCHY => %w(nodes/%{::trusted.certname} common),
    KEY_MERGE_BEHAVIOR => 'native'
  }

  def validate_config(config)
    unless Puppet[:strict] == :off
      Puppet.warn_once(:deprecation, 'hiera.yaml',
        "#{@config_path}: Use of 'hiera.yaml' version 3 is deprecated. It should be converted to version 5", config_path.to_s)
    end
    config[KEY_VERSION] ||= 3
    config[KEY_BACKENDS] ||= DEFAULT_CONFIG_HASH[KEY_BACKENDS]
    config[KEY_HIERARCHY] ||= DEFAULT_CONFIG_HASH[KEY_HIERARCHY]
    config[KEY_MERGE_BEHAVIOR] ||= DEFAULT_CONFIG_HASH[KEY_MERGE_BEHAVIOR]
    config[KEY_DEEP_MERGE_OPTIONS] ||= {}

    backends = [ config[KEY_BACKENDS] ].flatten

    # Create the final struct used for validation (backends are included as keys to arbitrary configs in the form of a hash)
    tf = Types::TypeFactory
    backend_elements = {}
    backends.each { |backend| backend_elements[tf.optional(backend)] = tf.hash_kv(Types::PStringType::NON_EMPTY, tf.any) }
    v3_struct = tf.struct(self.class.config_type.merge(backend_elements))

    Types::TypeAsserter.assert_instance_of(["The Lookup Configuration at '%s'", @config_path], v3_struct, config)
  end

  def merge_strategy
    @merge_strategy ||= create_merge_strategy
  end

  def version
    3
  end

  private

  def create_merge_strategy
    key = @config[KEY_MERGE_BEHAVIOR]
    case key
    when nil
      MergeStrategy.strategy(nil)
    when 'native'
      MergeStrategy.strategy(:first)
    when 'array'
      MergeStrategy.strategy(:unique)
    when 'deep', 'deeper'
      merge = { 'strategy' => key == 'deep' ? 'reverse_deep' : 'unconstrained_deep' }
      dm_options = @config[KEY_DEEP_MERGE_OPTIONS]
      merge.merge!(dm_options) if dm_options
      MergeStrategy.strategy(merge)
    end
  end
end

# @api private
class HieraConfigV4 < HieraConfig
  def self.config_type
    return @@CONFIG_TYPE if class_variable_defined?(:@@CONFIG_TYPE)
    tf = Types::TypeFactory
    nes_t = Types::PStringType::NON_EMPTY

    @@CONFIG_TYPE = tf.struct({
      KEY_VERSION => tf.range(4, 4),
      tf.optional(KEY_DATADIR) => nes_t,
      tf.optional(KEY_HIERARCHY) => tf.array_of(tf.struct(
        KEY_BACKEND => nes_t,
        KEY_NAME => nes_t,
        tf.optional(KEY_DATADIR) => nes_t,
        tf.optional(KEY_PATH) => nes_t,
        tf.optional(KEY_PATHS) => tf.array_of(nes_t)
      ))
    })
  end

  def create_configured_data_providers(lookup_invocation, parent_data_provider)
    default_datadir = @config[KEY_DATADIR]
    data_providers = {}

    @config[KEY_HIERARCHY].each do |he|
      name = he[KEY_NAME]
      raise Puppet::DataBinding::LookupError, "#{@config_path}: Name '#{name}' defined more than once" if data_providers.include?(name)
      original_paths = he[KEY_PATHS] || [he[KEY_PATH] || name]
      datadir = @config_root + (he[KEY_DATADIR] || default_datadir)
      provider_name = he[KEY_BACKEND]
      data_providers[name] = case
      when provider_name == 'json', provider_name == 'yaml'
        create_data_provider(name, parent_data_provider, KEY_DATA_HASH, "#{provider_name}_data", {},
          resolve_paths(datadir, original_paths, lookup_invocation, @config_path.nil?, ".#{provider_name}"))
      when provider_name == 'hocon' &&  Puppet.features.hocon?
        create_data_provider(name, parent_data_provider, KEY_DATA_HASH, 'hocon_data', {},
          resolve_paths(datadir, original_paths, lookup_invocation, @config_path.nil?, '.conf'))
      else
        raise Puppet::DataBinding::LookupError, "#{@config_path}: No data provider is registered for backend '#{provider_name}' "
      end
    end
    data_providers.values
  end

  def validate_config(config)
    unless Puppet[:strict] == :off
      Puppet.warn_once(:deprecation, 'hiera.yaml',
        "#{@config_path}: Use of 'hiera.yaml' version 4 is deprecated. It should be converted to version 5", config_path.to_s)
    end
    config[KEY_DATADIR] ||= 'data'
    config[KEY_HIERARCHY] ||= [{ KEY_NAME => 'common', KEY_BACKEND => 'yaml' }]
    Types::TypeAsserter.assert_instance_of(["The Lookup Configuration at '%s'", @config_path], self.class.config_type, config)
  end

  def version
    4
  end
end

# @api private
class HieraConfigV5 < HieraConfig
  def self.config_type
    return @@CONFIG_TYPE if class_variable_defined?(:@@CONFIG_TYPE_V5)
    tf = Types::TypeFactory
    nes_t = Types::PStringType::NON_EMPTY

    # Need alias here to avoid ridiculously long regexp burp in case of validation errors.
    uri_t = Pcore::TYPE_URI_ALIAS

    # The option name must start with a letter and end with a letter or digit. May contain underscore and dash.
    option_name_t = tf.pattern(/\A[A-Za-z](:?[0-9A-Za-z_-]*[0-9A-Za-z])?\z/)

    @@CONFIG_TYPE = tf.struct({
      KEY_VERSION => tf.range(5, 5),
      tf.optional(KEY_DEFAULTS) => tf.struct(
        {
          tf.optional(KEY_DATA_HASH) => nes_t,
          tf.optional(KEY_LOOKUP_KEY) => nes_t,
          tf.optional(KEY_DATA_DIG) => nes_t,
          tf.optional(KEY_DATADIR) => nes_t
        }),
      tf.optional(KEY_HIERARCHY) => tf.array_of(tf.struct(
        {
          KEY_NAME => nes_t,
          tf.optional(KEY_OPTIONS) => tf.hash_kv(option_name_t, tf.data),
          tf.optional(KEY_DATA_HASH) => nes_t,
          tf.optional(KEY_LOOKUP_KEY) => nes_t,
          tf.optional(KEY_V3_BACKEND) => nes_t,
          tf.optional(KEY_V4_DATA_HASH) => nes_t,
          tf.optional(KEY_DATA_DIG) => nes_t,
          tf.optional(KEY_PATH) => nes_t,
          tf.optional(KEY_PATHS) => tf.array_of(nes_t, tf.range(1, :default)),
          tf.optional(KEY_GLOB) => nes_t,
          tf.optional(KEY_GLOBS) => tf.array_of(nes_t, tf.range(1, :default)),
          tf.optional(KEY_URI) => uri_t,
          tf.optional(KEY_URIS) => tf.array_of(uri_t, tf.range(1, :default)),
          tf.optional(KEY_DATADIR) => nes_t
        }))
    })
  end

  def create_configured_data_providers(lookup_invocation, parent_data_provider)
    defaults = @config[KEY_DEFAULTS] || EMPTY_HASH
    datadir = defaults[KEY_DATADIR] || 'data'

    # Hashes enumerate their values in the order that the corresponding keys were inserted so it's safe to use
    # a hash for the data_providers.
    data_providers = {}
    @config[KEY_HIERARCHY].each do |he|
      name = he[KEY_NAME]
      raise Puppet::DataBinding::LookupError, "#{@config_path}: Name '#{name}' defined more than once" if data_providers.include?(name)
      function_kind = ALL_FUNCTION_KEYS.find { |key| he.include?(key) }
      if function_kind.nil?
        function_kind = FUNCTION_KEYS.find { |key| defaults.include?(key) }
        function_name = defaults[function_kind]
      else
        function_name = he[function_kind]
      end

      entry_datadir = @config_root + (he[KEY_DATADIR] || datadir)
      location_key = LOCATION_KEYS.find { |key| he.include?(key) }
      locations = case location_key
      when KEY_PATHS
        resolve_paths(entry_datadir, he[location_key], lookup_invocation, @config_path.nil?)
      when KEY_PATH
        resolve_paths(entry_datadir, [he[location_key]], lookup_invocation, @config_path.nil?)
      when KEY_GLOBS
        expand_globs(entry_datadir, he[location_key], lookup_invocation)
      when KEY_GLOB
        expand_globs(entry_datadir, [he[location_key]], lookup_invocation)
      when KEY_URIS
        expand_uris(he[location_key], lookup_invocation)
      when KEY_URI
        expand_uris([he[location_key]], lookup_invocation)
      else
        nil
      end
      next if @config_path.nil? && !locations.nil? && locations.empty? # Default config and no existing paths found
      options = he[KEY_OPTIONS]
      options = options.nil? ? EMPTY_HASH : interpolate(options, lookup_invocation, false)
      if(function_kind == KEY_V3_BACKEND)
        unless parent_data_provider.is_a?(GlobalDataProvider)
          # hiera3_backend is not allowed in environments and modules
          raise Puppet::DataBinding::LookupError, "#{@config_path}: '#{KEY_V3_BACKEND}' is only allowed in the global layer"
        end

        if function_name == 'json' || function_name == 'yaml' || function_name == 'hocon' &&  Puppet.features.hocon?
          # Disallow use of backends that have corresponding "data_hash" functions in version 5
          raise Puppet::DataBinding::LookupError, "#{@config_path}: Use \"#{KEY_DATA_HASH}: #{function_name}_data\" instead of \"#{KEY_V3_BACKEND}: #{function_name}\""
        end
        v3options = { :datadir => entry_datadir.to_s }
        options.each_pair { |k, v| v3options[k.to_sym] = v }
        data_providers[name] = create_hiera3_backend_provider(name, function_name, parent_data_provider, entry_datadir, locations, {
          :hierarchy =>
            locations.nil? ? [] : locations.map do |loc|
              path = loc.original_location
              path.end_with?(".#{function_name}") ? path[0..-(function_name.length + 2)] : path
            end,
          function_name.to_sym => v3options,
          :backends => [ function_name ],
          :logger => 'puppet'
        })
      else
        data_providers[name] = create_data_provider(name, parent_data_provider, function_kind, function_name, options, locations)
      end
    end
    data_providers.values
  end

  RESERVED_OPTION_KEYS = ['path', 'uri'].freeze

  DEFAULT_CONFIG_HASH = {
    KEY_VERSION => 5,
    KEY_DEFAULTS => {
      KEY_DATADIR => 'data',
      KEY_DATA_HASH => 'yaml_data'
    },
    KEY_HIERARCHY => [
      {
        KEY_NAME => 'Common',
        KEY_PATH => 'common.yaml',
      }
    ]
  }.freeze

  def validate_config(config)
    config[KEY_DEFAULTS] ||= DEFAULT_CONFIG_HASH[KEY_DEFAULTS]
    config[KEY_HIERARCHY] ||= DEFAULT_CONFIG_HASH[KEY_HIERARCHY]

    Types::TypeAsserter.assert_instance_of(["The Lookup Configuration at '%s'", @config_path], self.class.config_type, config)
    defaults = config[KEY_DEFAULTS]
    validate_defaults(defaults) unless defaults.nil?
    config[KEY_HIERARCHY].each do |he|
      name = he[KEY_NAME]
      case ALL_FUNCTION_KEYS.count { |key| he.include?(key) }
      when 0
        if defaults.nil? || FUNCTION_KEYS.count { |key| defaults.include?(key) } == 0
          raise Puppet::DataBinding::LookupError,
            "#{@config_path}: One of #{combine_strings(FUNCTION_KEYS)} must defined in hierarchy '#{name}'"
        end
      when 1
        # OK
      when 0
        raise Puppet::DataBinding::LookupError,
          "#{@config_path}: One of #{combine_strings(FUNCTION_KEYS)} must defined in hierarchy '#{name}'"
      else
        raise Puppet::DataBinding::LookupError,
          "#{@config_path}: Only one of #{combine_strings(FUNCTION_KEYS)} can be defined in hierarchy '#{name}'"
      end

      if LOCATION_KEYS.count { |key| he.include?(key) } > 1
        raise Puppet::DataBinding::LookupError,
          "#{@config_path}: Only one of #{combine_strings(LOCATION_KEYS)} can be defined in hierarchy '#{name}'"
      end

      options = he[KEY_OPTIONS]
      unless options.nil?
        RESERVED_OPTION_KEYS.each do |key|
          if options.include?(key)
            raise Puppet::DataBinding::LookupError, "#{@config_path}: Option key '#{key}' used in hierarchy '#{name}' is reserved by Puppet"
          end
        end
      end
    end
    config
  end

  def validate_defaults(defaults)
    case FUNCTION_KEYS.count { |key| defaults.include?(key) }
    when 0, 1
      # OK
    else
      raise Puppet::DataBinding::LookupError,
        "#{@config_path}: Only one of #{combine_strings(FUNCTION_KEYS)} can be defined in defaults"
    end
  end

  def version
    5
  end
end
end
end
