require 'puppet'
require 'getoptlong'
require 'puppet/util/watched_file'
require 'puppet/util/command_line/puppet_option_parser'
require 'forwardable'
require 'fileutils'

# The class for handling configuration files.
class Puppet::Settings
  extend Forwardable
  include Enumerable

  require 'puppet/settings/errors'
  require 'puppet/settings/base_setting'
  require 'puppet/settings/string_setting'
  require 'puppet/settings/enum_setting'
  require 'puppet/settings/symbolic_enum_setting'
  require 'puppet/settings/array_setting'
  require 'puppet/settings/file_setting'
  require 'puppet/settings/directory_setting'
  require 'puppet/settings/file_or_directory_setting'
  require 'puppet/settings/path_setting'
  require 'puppet/settings/boolean_setting'
  require 'puppet/settings/terminus_setting'
  require 'puppet/settings/duration_setting'
  require 'puppet/settings/ttl_setting'
  require 'puppet/settings/priority_setting'
  require 'puppet/settings/autosign_setting'
  require 'puppet/settings/config_file'
  require 'puppet/settings/value_translator'
  require 'puppet/settings/environment_conf'
  require 'puppet/settings/server_list_setting'

  # local reference for convenience
  PuppetOptionParser = Puppet::Util::CommandLine::PuppetOptionParser

  attr_accessor :files
  attr_reader :timer

  # These are the settings that every app is required to specify; there are
  # reasonable defaults defined in application.rb.
  REQUIRED_APP_SETTINGS = [:logdir, :confdir, :vardir, :codedir]

  # The acceptable sections of the puppet.conf configuration file.
  ALLOWED_SECTION_NAMES = ['main', 'master', 'agent', 'user'].freeze

  # This method is intended for puppet internal use only; it is a convenience method that
  # returns reasonable application default settings values for a given run_mode.
  def self.app_defaults_for_run_mode(run_mode)
    {
        :name     => run_mode.to_s,
        :run_mode => run_mode.name,
        :confdir  => run_mode.conf_dir,
        :codedir  => run_mode.code_dir,
        :vardir   => run_mode.var_dir,
        :rundir   => run_mode.run_dir,
        :logdir   => run_mode.log_dir,
    }
  end

  def self.default_certname()
    hostname = hostname_fact
    domain = domain_fact
    if domain and domain != ""
      fqdn = [hostname, domain].join(".")
    else
      fqdn = hostname
    end
    fqdn.to_s.gsub(/\.$/, '')
  end

  def self.hostname_fact()
    Facter.value :hostname
  end

  def self.domain_fact()
    Facter.value :domain
  end

  def self.default_config_file_name
    "puppet.conf"
  end

  # Create a new collection of config settings.
  def initialize
    @config = {}
    @shortnames = {}

    @created = []

    # Keep track of set values.
    @value_sets = {
      :cli => Values.new(:cli, @config),
      :memory => Values.new(:memory, @config),
      :application_defaults => Values.new(:application_defaults, @config),
      :overridden_defaults => Values.new(:overridden_defaults, @config),
    }
    @configuration_file = nil

    # And keep a per-environment cache
    @cache = Hash.new { |hash, key| hash[key] = {} }
    @values = Hash.new { |hash, key| hash[key] = {} }

    # The list of sections we've used.
    @used = []

    @hooks_to_call_on_application_initialization = []
    @deprecated_setting_names = []
    @deprecated_settings_that_have_been_configured = []

    @translate = Puppet::Settings::ValueTranslator.new
    @config_file_parser = Puppet::Settings::ConfigFile.new(@translate)
  end

  # Retrieve a config value
  # @param param [Symbol] the name of the setting
  # @return [Object] the value of the setting
  # @api private
  def [](param)
    if @deprecated_setting_names.include?(param)
      issue_deprecation_warning(setting(param), "Accessing '#{param}' as a setting is deprecated.")
    end
    value(param)
  end

  # Set a config value.  This doesn't set the defaults, it sets the value itself.
  # @param param [Symbol] the name of the setting
  # @param value [Object] the new value of the setting
  # @api private
  def []=(param, value)
    if @deprecated_setting_names.include?(param)
      issue_deprecation_warning(setting(param), "Modifying '#{param}' as a setting is deprecated.")
    end
    @value_sets[:memory].set(param, value)
    unsafe_flush_cache
  end

  # Create a new default value for the given setting. The default overrides are
  # higher precedence than the defaults given in defaults.rb, but lower
  # precedence than any other values for the setting. This allows one setting
  # `a` to change the default of setting `b`, but still allow a user to provide
  # a value for setting `b`.
  #
  # @param param [Symbol] the name of the setting
  # @param value [Object] the new default value for the setting
  # @api private
  def override_default(param, value)
    @value_sets[:overridden_defaults].set(param, value)
    unsafe_flush_cache
  end

  # Generate the list of valid arguments, in a format that GetoptLong can
  # understand, and add them to the passed option list.
  def addargs(options)
    # Add all of the settings as valid options.
    self.each { |name, setting|
      setting.getopt_args.each { |args| options << args }
    }

    options
  end

  # Generate the list of valid arguments, in a format that OptionParser can
  # understand, and add them to the passed option list.
  def optparse_addargs(options)
    # Add all of the settings as valid options.
    self.each { |name, setting|
      options << setting.optparse_args
    }

    options
  end

  # Is our setting a boolean setting?
  def boolean?(param)
    param = param.to_sym
    @config.include?(param) and @config[param].kind_of?(BooleanSetting)
  end

  # Remove all set values, potentially skipping cli values.
  def clear
    unsafe_clear
  end

  # Remove all set values, potentially skipping cli values.
  def unsafe_clear(clear_cli = true, clear_application_defaults = false)
    if clear_application_defaults
      @value_sets[:application_defaults] = Values.new(:application_defaults, @config)
      @app_defaults_initialized = false
    end

    if clear_cli
      @value_sets[:cli] = Values.new(:cli, @config)

      # Only clear the 'used' values if we were explicitly asked to clear out
      #  :cli values; otherwise, it may be just a config file reparse,
      #  and we want to retain this cli values.
      @used = []
    end

    @value_sets[:memory] = Values.new(:memory, @config)
    @value_sets[:overridden_defaults] = Values.new(:overridden_defaults, @config)

    @deprecated_settings_that_have_been_configured.clear
    @values.clear
    @cache.clear
  end
  private :unsafe_clear

  # Clears all cached settings for a particular environment to ensure
  # that changes to environment.conf are reflected in the settings if
  # the environment timeout has expired.
  #
  # param [String, Symbol] environment the  name of environment to clear settings for
  #
  # @api private
  def clear_environment_settings(environment)

    if environment.nil?
      return
    end

    @cache[environment.to_sym].clear
    @values[environment.to_sym] = {}
  end

  # Clear @cache, @used and the Environment.
  #
  # Whenever an object is returned by Settings, a copy is stored in @cache.
  # As long as Setting attributes that determine the content of returned
  # objects remain unchanged, Settings can keep returning objects from @cache
  # without re-fetching or re-generating them.
  #
  # Whenever a Settings attribute changes, such as @values or @preferred_run_mode,
  # this method must be called to clear out the caches so that updated
  # objects will be returned.
  def flush_cache
    unsafe_flush_cache
  end

  def unsafe_flush_cache
    clearused
  end
  private :unsafe_flush_cache

  def clearused
    @cache.clear
    @used = []
  end

  def global_defaults_initialized?()
    @global_defaults_initialized
  end

  def initialize_global_settings(args = [])
    raise Puppet::DevError, "Attempting to initialize global default settings more than once!" if global_defaults_initialized?

    # The first two phases of the lifecycle of a puppet application are:
    # 1) Parse the command line options and handle any of them that are
    #    registered, defined "global" puppet settings (mostly from defaults.rb).
    # 2) Parse the puppet config file(s).

    parse_global_options(args)
    parse_config_files

    @global_defaults_initialized = true
  end

  # This method is called during application bootstrapping.  It is responsible for parsing all of the
  # command line options and initializing the settings accordingly.
  #
  # It will ignore options that are not defined in the global puppet settings list, because they may
  # be valid options for the specific application that we are about to launch... however, at this point
  # in the bootstrapping lifecycle, we don't yet know what that application is.
  def parse_global_options(args)
    # Create an option parser
    option_parser = PuppetOptionParser.new
    option_parser.ignore_invalid_options = true

    # Add all global options to it.
    self.optparse_addargs([]).each do |option|
      option_parser.on(*option) do |arg|
        opt, val = Puppet::Settings.clean_opt(option[0], arg)
        handlearg(opt, val)
      end
    end

    option_parser.on('--run_mode',
                     "The effective 'run mode' of the application: master, agent, or user.",
                     :REQUIRED) do |arg|
      Puppet.settings.preferred_run_mode = arg
    end

    option_parser.parse(args)

    # remove run_mode options from the arguments so that later parses don't think
    # it is an unknown option.
    while option_index = args.index('--run_mode') do
      args.delete_at option_index
      args.delete_at option_index
    end
    args.reject! { |arg| arg.start_with? '--run_mode=' }
  end
  private :parse_global_options

  # A utility method (public, is used by application.rb and perhaps elsewhere) that munges a command-line
  # option string into the format that Puppet.settings expects.  (This mostly has to deal with handling the
  # "no-" prefix on flag/boolean options).
  #
  # @param [String] opt the command line option that we are munging
  # @param [String, TrueClass, FalseClass] val the value for the setting (as determined by the OptionParser)
  def self.clean_opt(opt, val)
    # rewrite --[no-]option to --no-option if that's what was given
    if opt =~ /\[no-\]/ and !val
      opt = opt.gsub(/\[no-\]/,'no-')
    end
    # otherwise remove the [no-] prefix to not confuse everybody
    opt = opt.gsub(/\[no-\]/, '')
    [opt, val]
  end


  def app_defaults_initialized?
    @app_defaults_initialized
  end

  def initialize_app_defaults(app_defaults)
    REQUIRED_APP_SETTINGS.each do |key|
      raise SettingsError, "missing required app default setting '#{key}'" unless app_defaults.has_key?(key)
    end

    app_defaults.each do |key, value|
      if key == :run_mode
        self.preferred_run_mode = value
      else
        @value_sets[:application_defaults].set(key, value)
        unsafe_flush_cache
      end
    end
    apply_metadata
    call_hooks_deferred_to_application_initialization
    issue_deprecations

    REQUIRED_APP_SETTINGS.each do |key|
      create_ancestors(Puppet[key])
    end

    @app_defaults_initialized = true
  end

  # Create ancestor directories.
  #
  # @param dir [String] absolute path for a required application default directory
  # @api private

  def create_ancestors(dir)
    parent_dir = File.dirname(dir)

    if !File.exist?(parent_dir)
      FileUtils.mkdir_p(parent_dir)
    end
  end
  private :create_ancestors

  def call_hooks_deferred_to_application_initialization(options = {})
    @hooks_to_call_on_application_initialization.each do |setting|
      begin
        setting.handle(self.value(setting.name))
      rescue InterpolationError => err
        raise InterpolationError, err, err.backtrace unless options[:ignore_interpolation_dependency_errors]
        #swallow. We're not concerned if we can't call hooks because dependencies don't exist yet
        #we'll get another chance after application defaults are initialized
      end
    end
  end
  private :call_hooks_deferred_to_application_initialization

  # Return a value's description.
  def description(name)
    if obj = @config[name.to_sym]
      obj.desc
    else
      nil
    end
  end

  def_delegator :@config, :each

  # Iterate over each section name.
  def eachsection
    yielded = []
    @config.each do |name, object|
      section = object.section
      unless yielded.include? section
        yield section
        yielded << section
      end
    end
  end

  # Returns a given setting by name
  # @param name [Symbol] The name of the setting to fetch
  # @return [Puppet::Settings::BaseSetting] The setting object
  def setting(param)
    param = param.to_sym
    @config[param]
  end

  # Handle a command-line argument.
  def handlearg(opt, value = nil)
    @cache.clear

    if value.is_a?(FalseClass)
      value = "false"
    elsif value.is_a?(TrueClass)
      value = "true"
    end

    value &&= @translate[value]
    str = opt.sub(/^--/,'')

    bool = true
    newstr = str.sub(/^no-/, '')
    if newstr != str
      str = newstr
      bool = false
    end
    str = str.intern

    if @config[str].is_a?(Puppet::Settings::BooleanSetting)
      if value == "" or value.nil?
        value = bool
      end
    end

    if s = @config[str]
      @deprecated_settings_that_have_been_configured << s if s.completely_deprecated?
    end

    @value_sets[:cli].set(str, value)
    unsafe_flush_cache
  end

  def include?(name)
    name = name.intern if name.is_a? String
    @config.include?(name)
  end

  # Prints the contents of a config file with the available config settings, or it
  # prints a single value of a config setting.
  def print_config_options
    env = value(:environment)
    val = value(:configprint)
    if val == "all"
      hash = {}
      each do |name, obj|
        val = value(name,env)
        val = val.inspect if val == ""
        hash[name] = val
      end
      hash.sort { |a,b| a[0].to_s <=> b[0].to_s }.each do |name, v|
        puts "#{name} = #{v}"
      end
    else
      val.split(/\s*,\s*/).sort.each do |v|
        if include?(v)
          #if there is only one value, just print it for back compatibility
          if v == val
            puts value(val,env)
            break
          end
          puts "#{v} = #{value(v,env)}"
        else
          puts "invalid setting: #{v}"
          return false
        end
      end
    end
    true
  end

  def generate_config
    puts to_config
    true
  end

  def generate_manifest
    puts to_manifest
    true
  end

  def print_configs
    return print_config_options if value(:configprint) != ""
    return generate_config if value(:genconfig)
    generate_manifest if value(:genmanifest)
  end

  def print_configs?
    (value(:configprint) != "" || value(:genconfig) || value(:genmanifest)) && true
  end

  # The currently configured run mode that is preferred for constructing the application configuration.
  def preferred_run_mode
    @preferred_run_mode_name || :user
  end

  # PRIVATE!  This only exists because we need a hook to validate the run mode when it's being set, and
  #  it should never, ever, ever, ever be called from outside of this file.
  # This method is also called when --run_mode MODE is used on the command line to set the default
  #
  # @param mode [String|Symbol] the name of the mode to have in effect
  # @api private
  def preferred_run_mode=(mode)
    mode = mode.to_s.downcase.intern
    raise ValidationError, "Invalid run mode '#{mode}'" unless [:master, :agent, :user].include?(mode)
    @preferred_run_mode_name = mode
    # Changing the run mode has far-reaching consequences. Flush any cached
    # settings so they will be re-generated.
    flush_cache
    mode
  end

  def parse_config(text, file = "text")
    begin
      data = @config_file_parser.parse_file(file, text, ALLOWED_SECTION_NAMES)
    rescue => detail
      Puppet.log_exception(detail, "Could not parse #{file}: #{detail}")
      return
    end

    # If we get here and don't have any data, we just return and don't muck with the current state of the world.
    return if data.nil?

    # If we get here then we have some data, so we need to clear out any
    # previous settings that may have come from config files.
    unsafe_clear(false, false)

    # Screen settings which have been deprecated and removed from puppet.conf
    # but are still valid on the command line and/or in environment.conf
    screen_non_puppet_conf_settings(data)

    # Make note of deprecated settings we will warn about later in initialization
    record_deprecations_from_puppet_conf(data)

    # And now we can repopulate with the values from our last parsing of the config files.
    @configuration_file = data

    # Determine our environment, if we have one.
    if @config[:environment]
      env = self.value(:environment).to_sym
    else
      env = "none"
    end

    # Call any hooks we should be calling.
    value_sets = value_sets_for(env, preferred_run_mode)
    @config.values.select(&:has_hook?).each do |setting|
      value_sets.each do |source|
        if source.include?(setting.name)
          # We still have to use value to retrieve the value, since
          # we want the fully interpolated value, not $vardir/lib or whatever.
          # This results in extra work, but so few of the settings
          # will have associated hooks that it ends up being less work this
          # way overall.
          if setting.call_hook_on_initialize?
            @hooks_to_call_on_application_initialization |= [ setting ]
          else
            setting.handle(ChainedValues.new(
              preferred_run_mode,
              env,
              value_sets,
              @config).interpolate(setting.name))
          end
          break
        end
      end
    end

    call_hooks_deferred_to_application_initialization :ignore_interpolation_dependency_errors => true
    apply_metadata
  end

  # Parse the configuration file.  Just provides thread safety.
  def parse_config_files
    file = which_configuration_file
    if Puppet::FileSystem.exist?(file)
      begin
        text = read_file(file)
      rescue => detail
        Puppet.log_exception(detail, "Could not load #{file}: #{detail}")
        return
      end
    else
      return
    end

    parse_config(text, file)
  end
  private :parse_config_files

  def main_config_file
    if explicit_config_file?
      return self[:config]
    else
      return File.join(Puppet::Util::RunMode[:master].conf_dir, config_file_name)
    end
  end
  private :main_config_file

  def user_config_file
    return File.join(Puppet::Util::RunMode[:user].conf_dir, config_file_name)
  end
  private :user_config_file

  # This method is here to get around some life-cycle issues.  We need to be
  # able to determine the config file name before the settings / defaults are
  # fully loaded.  However, we also need to respect any overrides of this value
  # that the user may have specified on the command line.
  #
  # The easiest way to do this is to attempt to read the setting, and if we
  # catch an error (meaning that it hasn't been set yet), we'll fall back to
  # the default value.
  def config_file_name
    begin
      return self[:config_file_name] if self[:config_file_name]
    rescue SettingsError
      # This just means that the setting wasn't explicitly set on the command line, so we will ignore it and
      #  fall through to the default name.
    end
    return self.class.default_config_file_name
  end
  private :config_file_name

  def apply_metadata
    # We have to do it in the reverse of the search path,
    # because multiple sections could set the same value
    # and I'm too lazy to only set the metadata once.
    if @configuration_file
      searchpath(nil, preferred_run_mode).reverse.each do |source|
        if source.type == :section && section = @configuration_file.sections[source.name]
          apply_metadata_from_section(section)
        end
      end
    end
  end
  private :apply_metadata

  def apply_metadata_from_section(section)
    section.settings.each do |setting|
      if setting.has_metadata? && type = @config[setting.name]
        type.set_meta(setting.meta)
      end
    end
  end

  SETTING_TYPES = {
      :string     => StringSetting,
      :file       => FileSetting,
      :directory  => DirectorySetting,
      :file_or_directory => FileOrDirectorySetting,
      :path       => PathSetting,
      :boolean    => BooleanSetting,
      :terminus   => TerminusSetting,
      :duration   => DurationSetting,
      :ttl        => TTLSetting,
      :array      => ArraySetting,
      :enum       => EnumSetting,
      :symbolic_enum   => SymbolicEnumSetting,
      :priority   => PrioritySetting,
      :autosign   => AutosignSetting,
      :server_list => ServerListSetting
  }

  # Create a new setting.  The value is passed in because it's used to determine
  # what kind of setting we're creating, but the value itself might be either
  # a default or a value, so we can't actually assign it.
  #
  # See #define_settings for documentation on the legal values for the ":type" option.
  def newsetting(hash)
    klass = nil
    hash[:section] = hash[:section].to_sym if hash[:section]

    if type = hash[:type]
      unless klass = SETTING_TYPES[type]
        raise ArgumentError, "Invalid setting type '#{type}'"
      end
      hash.delete(:type)
    else
      # The only implicit typing we still do for settings is to fall back to "String" type if they didn't explicitly
      # specify a type.  Personally I'd like to get rid of this too, and make the "type" option mandatory... but
      # there was a little resistance to taking things quite that far for now.  --cprice 2012-03-19
      klass = StringSetting
    end
    hash[:settings] = self
    setting = klass.new(hash)

    setting
  end

  # This has to be private, because it doesn't add the settings to @config
  private :newsetting

  # Iterate across all of the objects in a given section.
  def persection(section)
    section = section.to_sym
    self.each { |name, obj|
      if obj.section == section
        yield obj
      end
    }
  end

  # Reparse our config file, if necessary.
  def reparse_config_files
    if files
      if filename = any_files_changed?
        Puppet.notice "Config file #{filename} changed; triggering re-parse of all config files."
        parse_config_files
        reuse
      end
    end
  end

  def files
    return @files if @files
    @files = []
    [main_config_file, user_config_file].each do |path|
      if Puppet::FileSystem.exist?(path)
        @files << Puppet::Util::WatchedFile.new(path)
      end
    end
    @files
  end
  private :files

  # Checks to see if any of the config files have been modified
  # @return the filename of the first file that is found to have changed, or
  #   nil if no files have changed
  def any_files_changed?
    files.each do |file|
      return file.to_str if file.changed?
    end
    nil
  end
  private :any_files_changed?

  def reuse
    return unless defined?(@used)
    new = @used
    @used = []
    self.use(*new)
  end

  class SearchPathElement < Struct.new(:name, :type); end

  # The order in which to search for values, without defaults.
  #
  # @param environment [String,Symbol] symbolic reference to an environment name
  # @param run_mode [Symbol] symbolic reference to a Puppet run mode
  # @return [Array<SearchPathElement>]
  # @api private
  def configsearchpath(environment = nil, run_mode = preferred_run_mode)
    searchpath = [
      SearchPathElement.new(:memory, :values),
      SearchPathElement.new(:cli, :values),
    ]
    searchpath << SearchPathElement.new(environment.intern, :environment) if environment
    searchpath << SearchPathElement.new(run_mode, :section) if run_mode
    searchpath << SearchPathElement.new(:main, :section)
  end

  # The order in which to search for values.
  #
  # @param environment [String,Symbol] symbolic reference to an environment name
  # @param run_mode [Symbol] symbolic reference to a Puppet run mode
  # @return [Array<SearchPathElement>]
  # @api private
  def searchpath(environment = nil, run_mode = preferred_run_mode)
    searchpath = configsearchpath(environment, run_mode)
    searchpath << SearchPathElement.new(:application_defaults, :values)
    searchpath << SearchPathElement.new(:overridden_defaults, :values)
  end

  def service_user_available?
    return @service_user_available if defined?(@service_user_available)

    if self[:user]
      user = Puppet::Type.type(:user).new :name => self[:user], :audit => :ensure

      @service_user_available = user.exists?
    else
      @service_user_available = false
    end
  end

  def service_group_available?
    return @service_group_available if defined?(@service_group_available)

    if self[:group]
      group = Puppet::Type.type(:group).new :name => self[:group], :audit => :ensure

      @service_group_available = group.exists?
    else
      @service_group_available = false
    end
  end

  # Allow later inspection to determine if the setting was set on the
  # command line, or through some other code path.  Used for the
  # `dns_alt_names` option during cert generate. --daniel 2011-10-18
  def set_by_cli?(param)
    param = param.to_sym
    !@value_sets[:cli].lookup(param).nil?
  end

  # Get values from a search path entry.
  # @api private
  def searchpath_values(source)
    case source.type
    when :values
      @value_sets[source.name]
    when :section
      if @configuration_file && section = @configuration_file.sections[source.name]
        ValuesFromSection.new(source.name, section)
      end
    when :environment
      ValuesFromEnvironmentConf.new(source.name)
    else
      raise(Puppet::DevError, "Unknown searchpath case: #{source.type} for the #{source} settings path element.")
    end
  end

  # Allow later inspection to determine if the setting was set by user
  # config, rather than a default setting.
  def set_by_config?(param, environment = nil, run_mode = preferred_run_mode)
    param = param.to_sym
    configsearchpath(environment, run_mode).any? do |source|
      if vals = searchpath_values(source)
        vals.lookup(param)
      end
    end
  end

  # Patches the value for a param in a section.
  # This method is required to support the use case of unifying --dns-alt-names and
  # --dns_alt_names in the certificate face. Ideally this should be cleaned up.
  # See PUP-3684 for more information.
  # For regular use of setting a value, the method `[]=` should be used.
  # @api private
  #
  def patch_value(param, value, type)
    if @value_sets[type]
      @value_sets[type].set(param, value)
      unsafe_flush_cache
    end
  end

  # Define a group of settings.
  #
  # @param [Symbol] section a symbol to use for grouping multiple settings together into a conceptual unit.  This value
  #   (and the conceptual separation) is not used very often; the main place where it will have a potential impact
  #   is when code calls Settings#use method.  See docs on that method for further details, but basically that method
  #   just attempts to do any preparation that may be necessary before code attempts to leverage the value of a particular
  #   setting.  This has the most impact for file/directory settings, where #use will attempt to "ensure" those
  #   files / directories.
  # @param [Hash[Hash]] defs the settings to be defined.  This argument is a hash of hashes; each key should be a symbol,
  #   which is basically the name of the setting that you are defining.  The value should be another hash that specifies
  #   the parameters for the particular setting.  Legal values include:
  #    [:default] => not required; this is the value for the setting if no other value is specified (via cli, config file, etc.)
  #       For string settings this may include "variables", demarcated with $ or ${} which will be interpolated with values of other settings.
  #       The default value may also be a Proc that will be called only once to evaluate the default when the setting's value is retrieved.
  #    [:desc] => required; a description of the setting, used in documentation / help generation
  #    [:type] => not required, but highly encouraged!  This specifies the data type that the setting represents.  If
  #       you do not specify it, it will default to "string".  Legal values include:
  #       :string - A generic string setting
  #       :boolean - A boolean setting; values are expected to be "true" or "false"
  #       :file - A (single) file path; puppet may attempt to create this file depending on how the settings are used.  This type
  #           also supports additional options such as "mode", "owner", "group"
  #       :directory - A (single) directory path; puppet may attempt to create this file depending on how the settings are used.  This type
  #           also supports additional options such as "mode", "owner", "group"
  #       :path - This is intended to be used for settings whose value can contain multiple directory paths, represented
  #           as strings separated by the system path separator (e.g. system path, module path, etc.).
  #     [:mode] => an (optional) octal value to be used as the permissions/mode for :file and :directory settings
  #     [:owner] => optional owner username/uid for :file and :directory settings
  #     [:group] => optional group name/gid for :file and :directory settings
  #
  def define_settings(section, defs)
    section = section.to_sym
    call = []
    defs.each do |name, hash|
      raise ArgumentError, "setting definition for '#{name}' is not a hash!" unless hash.is_a? Hash

      name = name.to_sym
      hash[:name] = name
      hash[:section] = section
      raise ArgumentError, "Setting #{name} is already defined" if @config.include?(name)
      tryconfig = newsetting(hash)
      if short = tryconfig.short
        if other = @shortnames[short]
          raise ArgumentError, "Setting #{other.name} is already using short name '#{short}'"
        end
        @shortnames[short] = tryconfig
      end
      @config[name] = tryconfig

      # Collect the settings that need to have their hooks called immediately.
      # We have to collect them so that we can be sure we're fully initialized before
      # the hook is called.
      if tryconfig.has_hook?
        if tryconfig.call_hook_on_define?
          call << tryconfig
        elsif tryconfig.call_hook_on_initialize?
          @hooks_to_call_on_application_initialization |= [ tryconfig ]
        end
      end

      @deprecated_setting_names << name if tryconfig.deprecated?
    end

    call.each do |setting|
      setting.handle(self.value(setting.name))
    end
  end

  # Convert the settings we manage into a catalog full of resources that model those settings.
  def to_catalog(*sections)
    sections = nil if sections.empty?

    catalog = Puppet::Resource::Catalog.new("Settings", Puppet::Node::Environment::NONE)
    @config.keys.find_all { |key| @config[key].is_a?(FileSetting) }.each do |key|
      file = @config[key]
      next if file.value.nil?
      next unless (sections.nil? or sections.include?(file.section))
      next unless resource = file.to_resource
      next if catalog.resource(resource.ref)

      Puppet.debug {"Using settings: adding file resource '#{key}': '#{resource.inspect}'"}

      catalog.add_resource(resource)
    end

    add_user_resources(catalog, sections)
    add_environment_resources(catalog, sections)

    catalog
  end

  # Convert our list of config settings into a configuration file.
  def to_config
    str = %{The configuration file for #{Puppet.run_mode.name}.  Note that this file
is likely to have unused settings in it; any setting that's
valid anywhere in Puppet can be in any config file, even if it's not used.

Every section can specify three special parameters: owner, group, and mode.
These parameters affect the required permissions of any files specified after
their specification.  Puppet will sometimes use these parameters to check its
own configured state, so they can be used to make Puppet a bit more self-managing.

The file format supports octothorpe-commented lines, but not partial-line comments.

Generated on #{Time.now}.

}.gsub(/^/, "# ")

#         Add a section heading that matches our name.
    str += "[#{preferred_run_mode}]\n"
    eachsection do |section|
      persection(section) do |obj|
        str += obj.to_config + "\n" unless obj.name == :genconfig
      end
    end

    return str
  end

  # Convert to a parseable manifest
  def to_manifest
    catalog = to_catalog
    catalog.resource_refs.collect do |ref|
      catalog.resource(ref).to_manifest
    end.join("\n\n")
  end

  # Create the necessary objects to use a section.  This is idempotent;
  # you can 'use' a section as many times as you want.
  def use(*sections)
    sections = sections.collect { |s| s.to_sym }
    sections = sections.reject { |s| @used.include?(s) }

    return if sections.empty?

    Puppet.debug("Applying settings catalog for sections #{sections.join(', ')}")

    begin
      catalog = to_catalog(*sections).to_ral
    rescue => detail
      Puppet.log_and_raise(detail, "Could not create resources for managing Puppet's files and directories in sections #{sections.inspect}: #{detail}")
    end

    catalog.host_config = false
    catalog.apply do |transaction|
      if transaction.any_failed?
        report = transaction.report
        status_failures = report.resource_statuses.values.select { |r| r.failed? }
        status_fail_msg = status_failures.
          collect(&:events).
          flatten.
          select { |event| event.status == 'failure' }.
          collect { |event| "#{event.resource}: #{event.message}" }.join("; ")

        raise "Got #{status_failures.length} failure(s) while initializing: #{status_fail_msg}"
      end
    end

    sections.each { |s| @used << s }
    @used.uniq!
  end

  def valid?(param)
    param = param.to_sym
    @config.has_key?(param)
  end

  # Retrieve an object that can be used for looking up values of configuration
  # settings.
  #
  # @param environment [Symbol] The name of the environment in which to lookup
  # @param section [Symbol] The name of the configuration section in which to lookup
  # @return [Puppet::Settings::ChainedValues] An object to perform lookups
  # @api public
  def values(environment, section)
    @values[environment][section] ||= ChainedValues.new(
      section,
      environment,
      value_sets_for(environment, section),
      @config)
  end

  # Find the correct value using our search path.
  #
  # @param param [String, Symbol] The value to look up
  # @param environment [String, Symbol] The environment to check for the value
  # @param bypass_interpolation [true, false] Whether to skip interpolation
  #
  # @return [Object] The looked up value
  #
  # @raise [InterpolationError]
  def value(param, environment = nil, bypass_interpolation = false)
    param = param.to_sym
    environment &&= environment.to_sym

    setting = @config[param]

    # Short circuit to nil for undefined settings.
    return nil if setting.nil?

    # Check the cache first.  It needs to be a per-environment
    # cache so that we don't spread values from one env
    # to another.
    if @cache[environment||"none"].has_key?(param)
      return @cache[environment||"none"][param]
    elsif bypass_interpolation
      val = values(environment, self.preferred_run_mode).lookup(param)
    else
      val = values(environment, self.preferred_run_mode).interpolate(param)
    end

    @cache[environment||"none"][param] = val
    val
  end

  ##
  # (#15337) All of the logic to determine the configuration file to use
  #   should be centralized into this method.  The simplified approach is:
  #
  # 1. If there is an explicit configuration file, use that.  (--confdir or
  #    --config)
  # 2. If we're running as a root process, use the system puppet.conf
  #    (usually /etc/puppetlabs/puppet/puppet.conf)
  # 3. Otherwise, use the user puppet.conf (usually ~/.puppetlabs/etc/puppet/puppet.conf)
  #
  # @api private
  # @todo this code duplicates {Puppet::Util::RunMode#which_dir} as described
  #   in {https://projects.puppetlabs.com/issues/16637 #16637}
  def which_configuration_file
    if explicit_config_file? or Puppet.features.root? then
      return main_config_file
    else
      return user_config_file
    end
  end

  # This method just turns a file into a new ConfigFile::Conf instance
  # @param file [String] absolute path to the configuration file
  # @return [Puppet::Settings::ConfigFile::Conf]
  # @api private
  def parse_file(file, allowed_sections = [])
    @config_file_parser.parse_file(file, read_file(file), allowed_sections)
  end

  private

  DEPRECATION_REFS = {
    # intentionally empty. This could be repopulated if we deprecate more settings
    # and have reference links to associate with them
  }.freeze

  def screen_non_puppet_conf_settings(puppet_conf)
    puppet_conf.sections.values.each do |section|
      forbidden = section.settings.select { |setting| Puppet::Settings::EnvironmentConf::ENVIRONMENT_CONF_ONLY_SETTINGS.include?(setting.name) }
      raise(SettingsError, "Cannot set #{forbidden.map { |s| s.name }.join(", ")} settings in puppet.conf") if !forbidden.empty?
    end
  end

  # Record that we want to issue a deprecation warning later in the application
  # initialization cycle when we have settings bootstrapped to the point where
  # we can read the Puppet[:disable_warnings] setting.
  #
  # We are only recording warnings applicable to settings set in puppet.conf
  # itself.
  def record_deprecations_from_puppet_conf(puppet_conf)
    puppet_conf.sections.values.each do |section|
      section.settings.each do |conf_setting|
        if setting = self.setting(conf_setting.name)
          @deprecated_settings_that_have_been_configured << setting if setting.deprecated?
        end
      end
    end
  end

  def issue_deprecations
    @deprecated_settings_that_have_been_configured.each do |setting|
      issue_deprecation_warning(setting)
    end
  end

  def issue_deprecation_warning(setting, msg = nil)
    name = setting.name
    ref = DEPRECATION_REFS.find { |params,reference| params.include?(name) }
    ref = ref[1] if ref
    case
    when msg
      msg << " #{ref}" if ref
      Puppet.deprecation_warning(msg)
    when setting.completely_deprecated?
      Puppet.deprecation_warning("Setting #{name} is deprecated. #{ref}", "setting-#{name}")
    when setting.allowed_on_commandline?
      Puppet.deprecation_warning("Setting #{name} is deprecated in puppet.conf. #{ref}", "puppet-conf-setting-#{name}")
    end
  end

  def add_environment_resources(catalog, sections)
    path = self[:environmentpath]
    envdir = path.split(File::PATH_SEPARATOR).first if path
    configured_environment = self[:environment]
    if configured_environment == "production" && envdir && Puppet::FileSystem.exist?(envdir)
      configured_environment_path = File.join(envdir, configured_environment)
      if !Puppet::FileSystem.symlink?(configured_environment_path)
        catalog.add_resource(
          Puppet::Resource.new(:file,
                               configured_environment_path,
                               :parameters => { :ensure => 'directory' })
        )
      end
    end
  end

  def add_user_resources(catalog, sections)
    return unless Puppet.features.root?
    return if Puppet.features.microsoft_windows?
    return unless self[:mkusers]

    @config.each do |name, setting|
      next unless setting.respond_to?(:owner)
      next unless sections.nil? or sections.include?(setting.section)

      if user = setting.owner and user != "root" and catalog.resource(:user, user).nil?
        resource = Puppet::Resource.new(:user, user, :parameters => {:ensure => :present})
        resource[:gid] = self[:group] if self[:group]
        catalog.add_resource resource
      end
      if group = setting.group and ! %w{root wheel}.include?(group) and catalog.resource(:group, group).nil?
        catalog.add_resource Puppet::Resource.new(:group, group, :parameters => {:ensure => :present})
      end
    end
  end

  # Yield each search source in turn.
  def value_sets_for(environment, mode)
    searchpath(environment, mode).collect { |source| searchpath_values(source) }.compact
  end

  # Read the file in.
  # @api private
  def read_file(file)
    return Puppet::FileSystem.read(file, :encoding => 'utf-8')
  end

  # Private method for internal test use only; allows to do a comprehensive clear of all settings between tests.
  #
  # @return nil
  def clear_everything_for_tests()
    unsafe_clear(true, true)
    @configuration_file = nil
    @global_defaults_initialized = false
    @app_defaults_initialized = false
  end
  private :clear_everything_for_tests

  def explicit_config_file?
    # Figure out if the user has provided an explicit configuration file.  If
    # so, return the path to the file, if not return nil.
    #
    # The easiest way to determine whether an explicit one has been specified
    #  is to simply attempt to evaluate the value of ":config".  This will
    #  obviously be successful if they've passed an explicit value for :config,
    #  but it will also result in successful interpolation if they've only
    #  passed an explicit value for :confdir.
    #
    # If they've specified neither, then the interpolation will fail and we'll
    #  get an exception.
    #
    begin
      return true if self[:config]
    rescue InterpolationError
      # This means we failed to interpolate, which means that they didn't
      #  explicitly specify either :config or :confdir... so we'll fall out to
      #  the default value.
      return false
    end
  end
  private :explicit_config_file?

  # Lookup configuration setting value through a chain of different value sources.
  #
  # @api public
  class ChainedValues
    ENVIRONMENT_SETTING = "environment".freeze
    ENVIRONMENT_INTERPOLATION_ALLOWED = ['config_version'].freeze

    # @see Puppet::Settings.values
    # @api private
    def initialize(mode, environment, value_sets, defaults)
      @mode = mode
      @environment = environment
      @value_sets = value_sets
      @defaults = defaults
    end

    # Lookup the uninterpolated value.
    #
    # @param name [Symbol] The configuration setting name to look up
    # @return [Object] The configuration setting value or nil if the setting is not known
    # @api public
    def lookup(name)
      set = @value_sets.find do |value_set|
        value_set.include?(name)
      end
      if set
        value = set.lookup(name)
        if !value.nil?
          return value
        end
      end

      @defaults[name].default
    end

    # Lookup the interpolated value. All instances of `$name` in the value will
    # be replaced by performing a lookup of `name` and substituting the text
    # for `$name` in the original value. This interpolation is only performed
    # if the looked up value is a String.
    #
    # @param name [Symbol] The configuration setting name to look up
    # @return [Object] The configuration setting value or nil if the setting is not known
    # @api public
    def interpolate(name)
      setting = @defaults[name]

      if setting
        val = lookup(name)
        # if we interpolate code, all hell breaks loose.
        if name == :code
          val
        else
          # Convert it if necessary
          begin
            val = convert(val, name)
          rescue InterpolationError => err
            # This happens because we don't have access to the param name when the
            # exception is originally raised, but we want it in the message
            raise InterpolationError, "Error converting value for param '#{name}': #{err}", err.backtrace
          end

          setting.munge(val)
        end
      else
        nil
      end
    end

    private

    def convert(value, setting_name)
      case value
      when nil
        nil
      when String
        failed_environment_interpolation = false
        interpolated_value = value.gsub(/\$(\w+)|\$\{(\w+)\}/) do |expression|
          varname = $2 || $1
          interpolated_expression =
          if varname != ENVIRONMENT_SETTING || ok_to_interpolate_environment(setting_name)
            if varname == ENVIRONMENT_SETTING && @environment
              @environment
            elsif varname == "run_mode"
              @mode
            elsif !(pval = interpolate(varname.to_sym)).nil?
              pval
            else
              raise InterpolationError, "Could not find value for #{expression}"
            end
          else
            failed_environment_interpolation = true
            expression
          end
          interpolated_expression
        end
        if failed_environment_interpolation
          Puppet.warning("You cannot interpolate $environment within '#{setting_name}' when using directory environments.  Its value will remain #{interpolated_value}.")
        end
        interpolated_value
      else
        value
      end
    end

    def ok_to_interpolate_environment(setting_name)
      ENVIRONMENT_INTERPOLATION_ALLOWED.include?(setting_name.to_s)
    end
  end

  class Values
    extend Forwardable

    attr_reader :name

    def initialize(name, defaults)
      @name = name
      @values = {}
      @defaults = defaults
    end

    def_delegator :@values, :include?
    def_delegator :@values, :[], :lookup

    def set(name, value)
      default = @defaults[name]

      if !default
        raise ArgumentError,
          "Attempt to assign a value to unknown setting #{name.inspect}"
      end

      # This little exception-handling dance ensures that a hook is
      # able to check whether a value for itself has been explicitly
      # set, while still preserving the existing value if the hook
      # throws (as was existing behavior)
      old_value = @values[name]
      @values[name] = value
      begin
        if default.has_hook?
          default.handle(value)
        end
      rescue Exception => e
        @values[name] = old_value
        raise e
      end
     end

    def inspect
      %Q{<#{self.class}:#{self.object_id} @name="#{@name}" @values="#{@values}">}
    end
  end

  class ValuesFromSection
    attr_reader :name

    def initialize(name, section)
      @name = name
      @section = section
    end

    def include?(name)
      !@section.setting(name).nil?
    end

    def lookup(name)
      setting = @section.setting(name)
      if setting
        setting.value
      end
    end

    def inspect
      %Q{<#{self.class}:#{self.object_id} @name="#{@name}" @section="#{@section}">}
    end
  end

  # @api private
  class ValuesFromEnvironmentConf
    def initialize(environment_name)
      @environment_name = environment_name
    end

    def name
      @environment_name
    end

    def include?(name)
      if Puppet::Settings::EnvironmentConf::VALID_SETTINGS.include?(name) && conf
        return true
      end
      false
    end

    def lookup(name)
      return nil unless Puppet::Settings::EnvironmentConf::VALID_SETTINGS.include?(name)
      conf.send(name) if conf
    end

    def conf
      @conf ||= if environments = Puppet.lookup(:environments)
                  environments.get_conf(@environment_name)
                end
    end

    def inspect
      %Q{<#{self.class}:#{self.object_id} @environment_name="#{@environment_name}" @conf="#{@conf}">}
    end
  end
end
