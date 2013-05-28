require 'puppet'
require 'sync'
require 'getoptlong'
require 'puppet/util/watched_file'
require 'puppet/util/command_line/puppet_option_parser'
require 'puppet/settings/errors'
require 'puppet/settings/string_setting'
require 'puppet/settings/file_setting'
require 'puppet/settings/directory_setting'
require 'puppet/settings/path_setting'
require 'puppet/settings/boolean_setting'
require 'puppet/settings/terminus_setting'
require 'puppet/settings/duration_setting'
require 'puppet/settings/config_file'
require 'puppet/settings/value_translator'

# The class for handling configuration files.
class Puppet::Settings
  include Enumerable

  # local reference for convenience
  PuppetOptionParser = Puppet::Util::CommandLine::PuppetOptionParser

  attr_accessor :files
  attr_reader :timer

  # These are the settings that every app is required to specify; there are reasonable defaults defined in application.rb.
  REQUIRED_APP_SETTINGS = [:logdir, :confdir, :vardir]

  # This method is intended for puppet internal use only; it is a convenience method that
  # returns reasonable application default settings values for a given run_mode.
  def self.app_defaults_for_run_mode(run_mode)
    {
        :name     => run_mode.to_s,
        :run_mode => run_mode.name,
        :confdir  => run_mode.conf_dir,
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
    Facter["hostname"].value
  end

  def self.domain_fact()
    Facter["domain"].value
  end

  def self.default_config_file_name
    "puppet.conf"
  end

  # Create a new collection of config settings.
  def initialize
    @config = {}
    @shortnames = {}

    @created = []
    @searchpath = nil

    # Mutex-like thing to protect @values
    @sync = Sync.new

    # Keep track of set values.
    @values = Hash.new { |hash, key| hash[key] = {} }

    # Hold parsed metadata until run_mode is known
    @metas = {}

    # And keep a per-environment cache
    @cache = Hash.new { |hash, key| hash[key] = {} }

    # The list of sections we've used.
    @used = []

    @hooks_to_call_on_application_initialization = []

    @translate = Puppet::Settings::ValueTranslator.new
    @config_file_parser = Puppet::Settings::ConfigFile.new(@translate)
  end

  # Retrieve a config value
  def [](param)
    value(param)
  end

  # Set a config value.  This doesn't set the defaults, it sets the value itself.
  def []=(param, value)
    set_value(param, value, :memory)
  end

  # Generate the list of valid arguments, in a format that GetoptLong can
  # understand, and add them to the passed option list.
  def addargs(options)
    # Add all of the config parameters as valid options.
    self.each { |name, setting|
      setting.getopt_args.each { |args| options << args }
    }

    options
  end

  # Generate the list of valid arguments, in a format that OptionParser can
  # understand, and add them to the passed option list.
  def optparse_addargs(options)
    # Add all of the config parameters as valid options.
    self.each { |name, setting|
      options << setting.optparse_args
    }

    options
  end

  # Is our parameter a boolean parameter?
  def boolean?(param)
    param = param.to_sym
    @config.include?(param) and @config[param].kind_of?(BooleanSetting)
  end

  # Remove all set values, potentially skipping cli values.
  def clear
    @sync.synchronize do
      unsafe_clear
    end
  end

  # Remove all set values, potentially skipping cli values.
  def unsafe_clear(clear_cli = true, clear_application_defaults = false)
    @values.each do |name, values|
      next if ((name == :application_defaults) and !clear_application_defaults)
      next if ((name == :cli) and !clear_cli)
      @values.delete(name)
    end

    # Only clear the 'used' values if we were explicitly asked to clear out
    #  :cli values; otherwise, it may be just a config file reparse,
    #  and we want to retain this cli values.
    @used = [] if clear_cli

    @app_defaults_initialized = false if clear_application_defaults

    @cache.clear
  end
  private :unsafe_clear

  # This is mostly just used for testing.
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
  # @param [String, TrueClass, FalseClass] the value for the setting (as determined by the OptionParser)
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
        set_value(key, value, :application_defaults)
      end
    end
    apply_metadata
    call_hooks_deferred_to_application_initialization

    @app_defaults_initialized = true
  end

  def call_hooks_deferred_to_application_initialization(options = {})
    @hooks_to_call_on_application_initialization.each do |setting|
      begin
        setting.handle(self.value(setting.name))
      rescue InterpolationError => err
        raise err unless options[:ignore_interpolation_dependency_errors]
        #swallow. We're not concerned if we can't call hooks because dependencies don't exist yet
        #we'll get another chance after application defaults are initialized
      end
    end
  end
  private :call_hooks_deferred_to_application_initialization

  # Do variable interpolation on the value.
  def convert(value, environment = nil)
    return nil if value.nil?
    return value unless value.is_a? String
    newval = value.gsub(/\$(\w+)|\$\{(\w+)\}/) do |value|
      varname = $2 || $1
      if varname == "environment" and environment
        environment
      elsif varname == "run_mode"
        preferred_run_mode
      elsif pval = self.value(varname, environment)
        pval
      else
        raise InterpolationError, "Could not find value for #{value}"
      end
    end

    newval
  end

  # Return a value's description.
  def description(name)
    if obj = @config[name.to_sym]
      obj.desc
    else
      nil
    end
  end

  def each
    @config.each { |name, object|
      yield name, object
    }
  end

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

  # Return an object by name.
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

    set_value(str, value, :cli)
  end

  def include?(name)
    name = name.intern if name.is_a? String
    @config.include?(name)
  end

  # check to see if a short name is already defined
  def shortinclude?(short)
    short = short.intern if name.is_a? String
    @shortnames.include?(short)
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
      hash.sort { |a,b| a[0].to_s <=> b[0].to_s }.each do |name, val|
        puts "#{name} = #{val}"
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
          puts "invalid parameter: #{v}"
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

  # Return a given object's file metadata.
  def metadata(param)
    if obj = @config[param.to_sym] and obj.is_a?(FileSetting)
      return [:owner, :group, :mode].inject({}) do |meta, p|
        if v = obj.send(p)
          meta[p] = v
        end
        meta
      end
    else
      nil
    end
  end

  # Make a directory with the appropriate user, group, and mode
  def mkdir(default)
    obj = get_config_file_default(default)

    Puppet::Util::SUIDManager.asuser(obj.owner, obj.group) do
      mode = obj.mode || 0750
      Dir.mkdir(obj.value, mode)
    end
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
  end

  # Return all of the parameters associated with a given section.
  def params(section = nil)
    if section
      section = section.intern if section.is_a? String
      @config.find_all { |name, obj|
        obj.section == section
      }.collect { |name, obj|
        name
      }
    else
      @config.keys
    end
  end

  # Parse the configuration file.  Just provides thread safety.
  def parse_config_files
    @sync.synchronize do
      unsafe_parse(which_configuration_file)
    end

    call_hooks_deferred_to_application_initialization :ignore_interpolation_dependency_errors => true
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

  # Unsafely parse the file -- this isn't thread-safe and causes plenty of problems if used directly.
  def unsafe_parse(file)
    # build up a single data structure that contains the values from all of the parsed files.
    data = {}
    if FileTest.exist?(file)
      begin
        file_data = parse_file(file)

        # This is a little kludgy; basically we are merging a hash of hashes.  We can't use "merge" at the
        # outermost level or we risking losing data from the hash we're merging into.
        file_data.keys.each do |key|
          if data.has_key?(key)
            data[key].merge!(file_data[key])
          else
            data[key] = file_data[key]
          end
        end
      rescue => detail
        Puppet.log_exception(detail, "Could not parse #{file}: #{detail}")
        return
      end
    end

    # If we get here and don't have any data, we just return and don't muck with the current state of the world.
    return if data.empty?

    # If we get here then we have some data, so we need to clear out any previous settings that may have come from
    #  config files.
    unsafe_clear(false, false)

    # And now we can repopulate with the values from our last parsing of the config files.
    data.each do |area, values|
      @metas[area] = values.delete(:_meta)
      values.each do |key,value|
        set_value(key, value, area, :dont_trigger_handles => true, :ignore_bad_settings => true )
      end
    end

    # Determine our environment, if we have one.
    if @config[:environment]
      env = self.value(:environment).to_sym
    else
      env = "none"
    end

    # Call any hooks we should be calling.
    settings_with_hooks.each do |setting|
      each_source(env) do |source|
        if @values[source][setting.name]
          # We still have to use value to retrieve the value, since
          # we want the fully interpolated value, not $vardir/lib or whatever.
          # This results in extra work, but so few of the settings
          # will have associated hooks that it ends up being less work this
          # way overall.
          setting.handle(self.value(setting.name, env))
          break
        end
      end
    end

    # Take a best guess at metadata based on uninitialized run_mode
    apply_metadata
  end
  private :unsafe_parse

  def apply_metadata
    # We have to do it in the reverse of the search path,
    # because multiple sections could set the same value
    # and I'm too lazy to only set the metadata once.
    searchpath.reverse.each do |source|
      source = preferred_run_mode if source == :run_mode
      source = @name if (@name && source == :name)
      if meta = @metas[source]
        set_metadata(meta)
      end
    end
  end
  private :apply_metadata

  # Create a new setting.  The value is passed in because it's used to determine
  # what kind of setting we're creating, but the value itself might be either
  # a default or a value, so we can't actually assign it.
  #
  # See #define_settings for documentation on the legal values for the ":type" option.
  def newsetting(hash)
    klass = nil
    hash[:section] = hash[:section].to_sym if hash[:section]

    if type = hash[:type]
      unless klass = {
          :string     => StringSetting,
          :file       => FileSetting,
          :directory  => DirectorySetting,
          :path       => PathSetting,
          :boolean    => BooleanSetting,
          :terminus   => TerminusSetting,
          :duration   => DurationSetting,
      } [type]
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
      if FileTest.exist?(path)
        @files << Puppet::Util::WatchedFile.new(path)
      end
    end
    @files
  end
  private :files

  # Checks to see if any of the config files have been modified
  # @return the filename of the first file that is found to have changed, or nil if no files have changed
  def any_files_changed?
    files.each do |file|
      return file.file if file.changed?
    end
    nil
  end
  private :any_files_changed?

  def reuse
    return unless defined?(@used)
    @sync.synchronize do # yay, thread-safe
      new = @used
      @used = []
      self.use(*new)
    end
  end

  # The order in which to search for values.
  def searchpath(environment = nil)
    if environment
      [:cli, :memory, environment, :run_mode, :main, :application_defaults]
    else
      [:cli, :memory, :run_mode, :main, :application_defaults]
    end
  end

  # Get a list of objects per section
  def sectionlist
    sectionlist = []
    self.each { |name, obj|
      section = obj.section || "puppet"
      sections[section] ||= []
      sectionlist << section unless sectionlist.include?(section)
      sections[section] << obj
    }

    return sectionlist, sections
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
    !@values[:cli][param].nil?
  end

  def set_value(param, value, type, options = {})
    param = param.to_sym

    if !(setting = @config[param])
      if options[:ignore_bad_settings]
        return
      else
        raise ArgumentError,
          "Attempt to assign a value to unknown configuration parameter #{param.inspect}"
      end
    end

    setting.handle(value) if setting.has_hook? and not options[:dont_trigger_handles]

    @sync.synchronize do # yay, thread-safe

      @values[type][param] = value
      @cache.clear

      clearused

      # Clear the list of environments, because they cache, at least, the module path.
      # We *could* preferentially just clear them if the modulepath is changed,
      # but we don't really know if, say, the vardir is changed and the modulepath
      # is defined relative to it. We need the defined?(stuff) because of loading
      # order issues.
      Puppet::Node::Environment.clear if defined?(Puppet::Node) and defined?(Puppet::Node::Environment)
    end

    value
  end




  # Deprecated; use #define_settings instead
  def setdefaults(section, defs)
    Puppet.deprecation_warning("'setdefaults' is deprecated and will be removed; please call 'define_settings' instead")
    define_settings(section, defs)
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
  #    [:default] => required; this is a string value that will be used as a default value for a setting if no other
  #       value is specified (via cli, config file, etc.)  This string may include "variables", demarcated with $ or ${},
  #       which will be interpolated with values of other settings.
  #    [:desc] => required; a description of the setting, used in documentation / help generation
  #    [:type] => not required, but highly encouraged!  This specifies the data type that the setting represents.  If
  #       you do not specify it, it will default to "string".  Legal values include:
  #       :string - A generic string setting
  #       :boolean - A boolean setting; values are expected to be "true" or "false"
  #       :file - A (single) file path; puppet may attempt to create this file depending on how the settings are used.  This type
  #           also supports additional options such as "mode", "owner", "group"
  #       :directory - A (single) directory path; puppet may attempt to create this file depending on how the settings are used.  This type
  #           also supports additional options such as "mode", "owner", "group"
  #       :path - This is intended to be used for settings whose value can contain multiple directory paths, respresented
  #           as strings separated by the system path separator (e.g. system path, module path, etc.).
  #     [:mode] => an (optional) octal value to be used as the permissions/mode for :file and :directory settings
  #     [:owner] => optional owner username/uid for :file and :directory settings
  #     [:group] => optional group name/gid for :file and :directory settings
  #
  def define_settings(section, defs)
    section = section.to_sym
    call = []
    defs.each { |name, hash|
      raise ArgumentError, "setting definition for '#{name}' is not a hash!" unless hash.is_a? Hash

      name = name.to_sym
      hash[:name] = name
      hash[:section] = section
      raise ArgumentError, "Parameter #{name} is already defined" if @config.include?(name)
      tryconfig = newsetting(hash)
      if short = tryconfig.short
        if other = @shortnames[short]
          raise ArgumentError, "Parameter #{other.name} is already using short name '#{short}'"
        end
        @shortnames[short] = tryconfig
      end
      @config[name] = tryconfig

      # Collect the settings that need to have their hooks called immediately.
      # We have to collect them so that we can be sure we're fully initialized before
      # the hook is called.
      call << tryconfig if tryconfig.call_hook_on_define?
      @hooks_to_call_on_application_initialization << tryconfig if tryconfig.call_hook_on_initialize?
    }

    call.each { |setting| setting.handle(self.value(setting.name)) }
  end

  # Convert the settings we manage into a catalog full of resources that model those settings.
  def to_catalog(*sections)
    sections = nil if sections.empty?

    catalog = Puppet::Resource::Catalog.new("Settings")

    @config.keys.find_all { |key| @config[key].is_a?(FileSetting) }.each do |key|
      file = @config[key]
      next unless (sections.nil? or sections.include?(file.section))
      next unless resource = file.to_resource
      next if catalog.resource(resource.ref)

      Puppet.debug("Using settings: adding file resource '#{key}': '#{resource.inspect}'")

      catalog.add_resource(resource)
    end

    add_user_resources(catalog, sections)

    catalog
  end

  # Convert our list of config settings into a configuration file.
  def to_config
    str = %{The configuration file for #{Puppet.run_mode.name}.  Note that this file
is likely to have unused configuration parameters in it; any parameter that's
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
    @sync.synchronize do # yay, thread-safe
      sections = sections.reject { |s| @used.include?(s) }

      return if sections.empty?

      begin
        catalog = to_catalog(*sections).to_ral
      rescue => detail
        Puppet.log_and_raise(detail, "Could not create resources for managing Puppet's files and directories in sections #{sections.inspect}: #{detail}")
      end

      catalog.host_config = false
      catalog.apply do |transaction|
        if transaction.any_failed?
          report = transaction.report
          failures = report.logs.find_all { |log| log.level == :err }
          raise "Got #{failures.length} failure(s) while initializing: #{failures.collect { |l| l.to_s }.join("; ")}"
        end
      end

      sections.each { |s| @used << s }
      @used.uniq!
    end
  end

  def valid?(param)
    param = param.to_sym
    @config.has_key?(param)
  end

  def uninterpolated_value(param, environment = nil)
    param = param.to_sym
    environment &&= environment.to_sym

    # See if we can find it within our searchable list of values
    val = find_value(environment, param)

    # If we didn't get a value, use the default
    val = @config[param].default if val.nil?

    val
  end

  def find_value(environment, param)
      each_source(environment) do |source|
        # Look for the value.  We have to test the hash for whether
        # it exists, because the value might be false.
        @sync.synchronize do
          return @values[source][param] if @values[source].include?(param)
        end
      end
      return nil
  end
  private :find_value

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

    # Short circuit to nil for undefined parameters.
    return nil unless @config.include?(param)

    # Yay, recursion.
    #self.reparse unless [:config, :filetimeout].include?(param)

    # Check the cache first.  It needs to be a per-environment
    # cache so that we don't spread values from one env
    # to another.
    if @cache[environment||"none"].has_key?(param)
      return @cache[environment||"none"][param]
    end

    val = uninterpolated_value(param, environment)

    return val if bypass_interpolation
    if param == :code
      # if we interpolate code, all hell breaks loose.
      return val
    end

    # Convert it if necessary
    begin
      val = convert(val, environment)
    rescue InterpolationError => err
      # This happens because we don't have access to the param name when the
      # exception is originally raised, but we want it in the message
      raise InterpolationError, "Error converting value for param '#{param}': #{err}", err.backtrace
    end

    val = setting.munge(val) if setting.respond_to?(:munge)
    # And cache it
    @cache[environment||"none"][param] = val
    val
  end

  # Open a file with the appropriate user, group, and mode
  def write(default, *args, &bloc)
    obj = get_config_file_default(default)
    writesub(default, value(obj.name), *args, &bloc)
  end

  # Open a non-default file under a default dir with the appropriate user,
  # group, and mode
  def writesub(default, file, *args, &bloc)
    obj = get_config_file_default(default)
    chown = nil
    if Puppet.features.root?
      chown = [obj.owner, obj.group]
    else
      chown = [nil, nil]
    end

    Puppet::Util::SUIDManager.asuser(*chown) do
      mode = obj.mode ? obj.mode.to_i : 0640
      args << "w" if args.empty?

      args << mode

      # Update the umask to make non-executable files
      Puppet::Util.withumask(File.umask ^ 0111) do
        File.open(file, *args) do |file|
          yield file
        end
      end
    end
  end

  def readwritelock(default, *args, &bloc)
    file = value(get_config_file_default(default).name)
    tmpfile = file + ".tmp"
    sync = Sync.new
    raise Puppet::DevError, "Cannot create #{file}; directory #{File.dirname(file)} does not exist" unless FileTest.directory?(File.dirname(tmpfile))

    sync.synchronize(Sync::EX) do
      File.open(file, ::File::CREAT|::File::RDWR, 0600) do |rf|
        rf.lock_exclusive do
          if File.exist?(tmpfile)
            raise Puppet::Error, ".tmp file already exists for #{file}; Aborting locked write. Check the .tmp file and delete if appropriate"
          end

          # If there's a failure, remove our tmpfile
          begin
            writesub(default, tmpfile, *args, &bloc)
          rescue
            File.unlink(tmpfile) if FileTest.exist?(tmpfile)
            raise
          end

          begin
            File.rename(tmpfile, file)
          rescue => detail
            Puppet.err "Could not rename #{file} to #{tmpfile}: #{detail}"
            File.unlink(tmpfile) if FileTest.exist?(tmpfile)
          end
        end
      end
    end
  end

  private

  def get_config_file_default(default)
    obj = nil
    unless obj = @config[default]
      raise ArgumentError, "Unknown default #{default}"
    end

    raise ArgumentError, "Default #{default} is not a file" unless obj.is_a? FileSetting

    obj
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
  def each_source(environment)
    searchpath(environment).each do |source|

      # Modify the source as necessary.
      source = self.preferred_run_mode if source == :run_mode
      yield source
    end
  end

  # Return all settings that have associated hooks; this is so
  # we can call them after parsing the configuration file.
  def settings_with_hooks
    @config.values.find_all { |setting| setting.has_hook? }
  end

  # This method just turns a file in to a hash of hashes.
  def parse_file(file)
    @config_file_parser.parse_file(file, read_file(file))
  end

  # Read the file in.
  def read_file(file)
    begin
      return File.read(file)
    rescue Errno::ENOENT
      raise ArgumentError, "No such file #{file}"
    rescue Errno::EACCES
      raise ArgumentError, "Permission denied to file #{file}"
    end
  end

  # Set file metadata.
  def set_metadata(meta)
    meta.each do |var, values|
      values.each do |param, value|
        @sync.synchronize do # yay, thread-safe
          @config[var].send(param.to_s + "=", value)
        end
      end
    end
  end

  # Private method for internal test use only; allows to do a comprehensive clear of all settings between tests.
  #
  # @return nil
  def clear_everything_for_tests()
    @sync.synchronize do
      unsafe_clear(true, true)
      @global_defaults_initialized = false
      @app_defaults_initialized = false
    end
  end
  private :clear_everything_for_tests

  ##
  # (#15337) All of the logic to determine the configuration file to use
  #   should be centralized into this method.  The simplified approach is:
  #
  # 1. If there is an explicit configuration file, use that.  (--confdir or
  #    --config)
  # 2. If we're running as a root process, use the system puppet.conf
  #    (usually /etc/puppet/puppet.conf)
  # 3. Otherwise, use the user puppet.conf (usually ~/.puppet/puppet.conf)
  #
  # @todo this code duplicates {Puppet::Util::RunMode#which_dir} as described
  #   in {http://projects.puppetlabs.com/issues/16637 #16637}
  def which_configuration_file
    if explicit_config_file? or Puppet.features.root? then
      return main_config_file
    else
      return user_config_file
    end
  end

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

end
