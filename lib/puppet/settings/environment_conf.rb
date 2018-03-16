# Configuration settings for a single directory Environment.
# @api private
class Puppet::Settings::EnvironmentConf

  ENVIRONMENT_CONF_ONLY_SETTINGS = [:modulepath, :manifest, :config_version].freeze
  VALID_SETTINGS = (ENVIRONMENT_CONF_ONLY_SETTINGS + [:environment_timeout, :environment_data_provider, :static_catalogs, :rich_data]).freeze

  # Given a path to a directory environment, attempts to load and parse an
  # environment.conf in ini format, and return an EnvironmentConf instance.
  #
  # An environment.conf is optional, so if the file itself is missing, or
  # empty, an EnvironmentConf with default values will be returned.
  #
  # @note logs warnings if the environment.conf contains any ini sections,
  # or has settings other than the three handled for directory environments
  # (:manifest, :modulepath, :config_version)
  #
  # @param path_to_env [String] path to the directory environment
  # @param global_module_path [Array<String>] the installation's base modulepath
  #   setting, appended to default environment modulepaths
  # @return [EnvironmentConf] the parsed EnvironmentConf object
  def self.load_from(path_to_env, global_module_path)
    path_to_env = File.expand_path(path_to_env)
    conf_file = File.join(path_to_env, 'environment.conf')

    begin
      config = Puppet.settings.parse_file(conf_file)
      validate(conf_file, config)
      section = config.sections[:main]
    rescue Errno::ENOENT
      # environment.conf is an optional file
    end

    new(path_to_env, section, global_module_path)
  end

  # Provides a configuration object tied directly to the passed environment.
  # Configuration values are exactly those returned by the environment object,
  # without interpolation.  This is a special case for the default configured
  # environment returned by the Puppet::Environments::StaticPrivate loader.
  def self.static_for(environment, environment_timeout = 0, static_catalogs = false, rich_data = false)
    Static.new(environment, environment_timeout, static_catalogs, nil, rich_data)
  end

  attr_reader :section, :path_to_env, :global_modulepath

  # Create through EnvironmentConf.load_from()
  def initialize(path_to_env, section, global_module_path)
    @path_to_env = path_to_env
    @section = section
    @global_module_path = global_module_path
  end

  def manifest
    puppet_conf_manifest = Pathname.new(Puppet.settings.value(:default_manifest))
    disable_per_environment_manifest = Puppet.settings.value(:disable_per_environment_manifest)

    fallback_manifest_directory =
    if puppet_conf_manifest.absolute?
      puppet_conf_manifest.to_s
    else
      File.join(@path_to_env, puppet_conf_manifest.to_s)
    end

    if disable_per_environment_manifest
      environment_conf_manifest = absolute(raw_setting(:manifest))
      if environment_conf_manifest && fallback_manifest_directory != environment_conf_manifest
        #TRANSLATORS 'disable_per_environment_manifest' is a setting and 'environment.conf' is a file name and should not be translated
        message = _("The 'disable_per_environment_manifest' setting is true, but the environment located at %{path_to_env} has a manifest setting in its environment.conf of '%{environment_conf}' which does not match the default_manifest setting '%{puppet_conf}'.") %
            { path_to_env: @path_to_env, environment_conf: environment_conf_manifest, puppet_conf: puppet_conf_manifest }
        message += ' ' + _("If this environment is expecting to find modules in '%{environment_conf}', they will not be available!") % { environment_conf: environment_conf_manifest }
        Puppet.err(message)
      end
      fallback_manifest_directory.to_s
    else
      get_setting(:manifest, fallback_manifest_directory) do |manifest|
        absolute(manifest)
      end
    end
  end

  def environment_timeout
    # gen env specific config or use the default value
    get_setting(:environment_timeout, Puppet.settings.value(:environment_timeout)) do |ttl|
      # munges the string form statically without really needed the settings system, only
      # its ability to munge "4s, 3m, 5d, and 'unlimited' into seconds - if already munged into
      # numeric form, the TTLSetting handles that.
      Puppet::Settings::TTLSetting.munge(ttl, 'environment_timeout')
    end
  end

  def environment_data_provider
    get_setting(:environment_data_provider, Puppet.settings.value(:environment_data_provider)) do |value|
      value
    end
  end

  def modulepath
    default_modulepath = [File.join(@path_to_env, "modules")] + @global_module_path
    get_setting(:modulepath, default_modulepath) do |modulepath|
      path = modulepath.kind_of?(String) ?
        modulepath.split(File::PATH_SEPARATOR) :
        modulepath
      path.map { |p| expand_glob(absolute(p)) }.flatten.join(File::PATH_SEPARATOR)
    end
  end

  def rich_data
    get_setting(:rich_data, Puppet.settings.value(:rich_data)) do |value|
      value
    end
  end

  def static_catalogs
    get_setting(:static_catalogs, Puppet.settings.value(:static_catalogs)) do |value|
      value
    end
  end

  def config_version
    get_setting(:config_version) do |config_version|
      absolute(config_version)
    end
  end

  def raw_setting(setting_name)
    setting = section.setting(setting_name) if section
    setting.value if setting
  end

  private

  def self.validate(path_to_conf_file, config)
    valid = true
    section_keys = config.sections.keys
    main = config.sections[:main]
    if section_keys.size > 1
      # warn once per config file path
      Puppet.warn_once(
        :invalid_settings_section, "EnvironmentConf-section:#{path_to_conf_file}",
        _("Invalid sections in environment.conf at '%{path_to_conf_file}'. Environment conf may not have sections. The following sections are being ignored: '%{sections}'") % {
          path_to_conf_file: path_to_conf_file,
          sections: (section_keys - [:main]).join(',')
        })
      valid = false
    end

    extraneous_settings = main.settings.map(&:name) - VALID_SETTINGS
    if !extraneous_settings.empty?
      # warn once per config file path
      Puppet.warn_once(
        :invalid_settings, "EnvironmentConf-settings:#{path_to_conf_file}",
        _("Invalid settings in environment.conf at '%{path_to_conf_file}'. The following unknown setting(s) are being ignored: %{ignored_settings}") % {
          path_to_conf_file: path_to_conf_file,
          ignored_settings: extraneous_settings.join(', ')
        })
      valid = false
    end

    return valid
  end

  def get_setting(setting_name, default = nil)
    value = raw_setting(setting_name)
    value = default if value.nil?
    yield value
  end

  def expand_glob(path)
    return nil if path.nil?
    if path =~ /[*?\[\{]/
      Dir.glob(path)
    else
      path
    end
  end

  def absolute(path)
    return nil if path.nil?
    if path =~ /^\$/
      # Path begins with $something interpolatable
      path
    else
      Puppet::FileSystem.expand_path(path, @path_to_env)
    end
  end

  # Models configuration for an environment that is not loaded from a directory.
  #
  # @api private
  class Static
    attr_reader :environment_timeout
    attr_reader :environment_data_provider
    attr_reader :rich_data
    attr_reader :static_catalogs

    def initialize(environment, environment_timeout, static_catalogs, environment_data_provider = nil, rich_data = false)
      @environment = environment
      @environment_timeout = environment_timeout
      @static_catalogs = static_catalogs
      @environment_data_provider = environment_data_provider
      @rich_data = rich_data
    end

    def path_to_env
      nil
    end

    def manifest
      @environment.manifest
    end

    def modulepath
      @environment.modulepath.join(File::PATH_SEPARATOR)
    end

    def config_version
      @environment.config_version
    end
  end

end
