require_relative 'data_dig_function_provider'
require_relative 'data_hash_function_provider'
require_relative 'lookup_key_function_provider'
require_relative 'location_resolver'

module Puppet::Pops
module Lookup
# @api private
class LookupConfig
  include LocationResolver
  include LabelProvider

  CONFIG_FILE_NAME = 'lookup.yaml'

  KEY_NAME = 'name'.freeze
  KEY_VERSION = 'version'.freeze
  KEY_DATADIR = 'datadir'.freeze
  KEY_HIERARCHY = 'hierarchy'.freeze
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
  KEY_V4_DATA_HASH = V4DataHashFunctionProvider::TAG

  DEFAULT_CONFIG = {
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

  FUNCTION_KEYS = [KEY_DATA_HASH, KEY_LOOKUP_KEY, KEY_DATA_DIG]
  ALL_FUNCTION_KEYS = FUNCTION_KEYS + [KEY_V4_DATA_HASH]
  LOCATION_KEYS = [KEY_PATH, KEY_PATHS, KEY_GLOB, KEY_GLOBS, KEY_URI, KEY_URIS]
  FUNCTION_PROVIDERS = {
    KEY_DATA_HASH => DataHashFunctionProvider,
    KEY_DATA_DIG => DataDigFunctionProvider,
    KEY_LOOKUP_KEY => LookupKeyFunctionProvider,
    KEY_V4_DATA_HASH => V4DataHashFunctionProvider
  }

  def self.legacy_function_config(function_name)
    unless Puppet[:strict] == :off
      Puppet.warn_once(:deprecation, 'legacy_provider_function',
        "Using of legacy data provider function '#{function_name}'. Please convert to a 'data_hash' function")
    end
    self.new(
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

  def self.config_type
    @@CONFIG_TYPE ||= create_config_type
  end

  def self.config_exist?(config_root)
    config_path = config_root + CONFIG_FILE_NAME
    config_path.exist?
  end

  def self.create_config_type
    tf = Types::TypeFactory

    # Need alias here to avoid ridiculously long regexp burp in case of validation errors.
    uri_t = Pcore::TYPE_URI_ALIAS

    # The option name must start with a letter and end with a letter or digit. May contain underscore and dash.
    option_name_t = tf.pattern(/\A[A-Za-z](:?[0-9A-Za-z_-]*[0-9A-Za-z])?\z/)
    nes_t = Types::PStringType::NON_EMPTY
    tf.struct({
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

  private_class_method :create_config_type

  attr_reader :config_path, :version

  # Creates a new LookupConfig from the given _config_root_. This is where the 'lookup.yaml' is expected to be found
  # and is also the base location used when resolving relative paths.
  #
  # @param config_root [Pathname] Absolute path to the configuration root
  def initialize(config_root)
    if config_root.is_a?(Hash)
      @config = config_root
      @config_root = nil
      @config_path = nil
    else
      @config_root = config_root
      @config_path = config_root + CONFIG_FILE_NAME
      if @config_path.exist?
        config = YAML.load_file(@config_path)
        config[KEY_DEFAULTS] ||= DEFAULT_CONFIG[KEY_DEFAULTS]
        config[KEY_HIERARCHY] ||= DEFAULT_CONFIG[KEY_HIERARCHY]
        @config = validate_config(config)
      else
        @config = DEFAULT_CONFIG
        @config_path = nil
      end
    end
    @version = @config[KEY_VERSION]
  end

  # Creates the data providers for this config
  #
  # @param lookup_invocation [Invocation] Invocation data containing scope, overrides, and defaults
  # @param parent_data_provider [DataProvider] The data provider that loaded this configuration
  # @return [Array<DataProvider>] the created providers
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

      entry_datadir = @config_root.nil? ? nil : @config_root + (he[KEY_DATADIR] || datadir)
      location_key = LOCATION_KEYS.find { |key| he.include?(key) }
      locations = case location_key
      when KEY_PATHS
        resolve_paths(entry_datadir, he[location_key], lookup_invocation)
      when KEY_PATH
        resolve_paths(entry_datadir, [he[location_key]], lookup_invocation)
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
      options = he[KEY_OPTIONS]
      options = options.nil? ? EMPTY_HASH : interpolate(options, lookup_invocation, false)
      data_providers[name] = create_data_provider(name, parent_data_provider, function_kind, function_name, options, locations)
    end
    data_providers.values
  end

  def name
    "lookup version #{version}"
  end

  private

  def create_data_provider(name, parent_data_provider, function_kind, function_name, options, locations)
    FUNCTION_PROVIDERS[function_kind].new(name, parent_data_provider, function_name, options, locations)
  end

  def validate_config(config)
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
    end
    config
  end

  def validate_defaults(defaults)
    case FUNCTION_KEYS.count { |key| defaults.include?(key) }
    when 0, 1
      # OK
    else
      raise Puppet::DataBinding::LookupError,
            "#{@config_path}: Only one of #{combine_strings(FUNCTION_KEYS)} can defined in defaults"
    end
  end
end
end
end
