require 'puppet/util'
require 'puppet/util/cacher'
require 'monitor'
require 'puppet/parser/parser_factory'

# Just define it, so this class has fewer load dependencies.
class Puppet::Node
end

# Puppet::Node::Environment acts as a container for all configuration
# that is expected to vary between environments.
#
# ## The root environment
#
# In addition to normal environments that are defined by the user,there is a
# special 'root' environment. It is defined as an instance variable on the
# Puppet::Node::Environment metaclass. The environment name is `*root*` and can
# be accessed by looking up the `:root_environment` using {Puppet.lookup}.
#
# The primary purpose of the root environment is to contain parser functions
# that are not bound to a specific environment. The main case for this is for
# logging functions. Logging functions are attached to the 'root' environment
# when {Puppet::Parser::Functions.reset} is called.
class Puppet::Node::Environment
  include Puppet::Util::Cacher

  NO_MANIFEST = :no_manifest

  # @api private
  def self.seen
    @seen ||= {}
  end

  # Create a new environment with the given name, or return an existing one
  #
  # The environment class memoizes instances so that attempts to instantiate an
  # environment with the same name with an existing environment will return the
  # existing environment.
  #
  # @overload self.new(environment)
  #   @param environment [Puppet::Node::Environment]
  #   @return [Puppet::Node::Environment] the environment passed as the param,
  #     this is implemented so that a calling class can use strings or
  #     environments interchangeably.
  #
  # @overload self.new(string)
  #   @param string [String, Symbol]
  #   @return [Puppet::Node::Environment] An existing environment if it exists,
  #     else a new environment with that name
  #
  # @overload self.new()
  #   @return [Puppet::Node::Environment] The environment as set by
  #     Puppet.settings[:environment]
  #
  # @api public
  def self.new(name = nil)
    return name if name.is_a?(self)
    name ||= Puppet.settings.value(:environment)

    raise ArgumentError, "Environment name must be specified" unless name

    symbol = name.to_sym

    return seen[symbol] if seen[symbol]

    obj = self.create(symbol,
             split_path(Puppet.settings.value(:modulepath, symbol)),
             Puppet.settings.value(:manifest, symbol),
             Puppet.settings.value(:config_version, symbol))
    seen[symbol] = obj
  end

  # Create a new environment with the given name
  #
  # @param name [Symbol] the name of the
  # @param modulepath [Array<String>] the list of paths from which to load modules
  # @param manifest [String] the path to the manifest for the environment or
  # the constant Puppet::Node::Environment::NO_MANIFEST if there is none.
  # @param config_version [String] path to a script whose output will be added
  #   to report logs (optional)
  # @return [Puppet::Node::Environment]
  #
  # @api public
  def self.create(name, modulepath, manifest = NO_MANIFEST, config_version = nil)
    obj = self.allocate
    obj.send(:initialize,
             name,
             expand_dirs(extralibs() + modulepath),
             manifest == NO_MANIFEST ? manifest : File.expand_path(manifest),
             config_version)
    obj
  end

  # A "reference" to a remote environment. The created environment instance
  # isn't expected to exist on the local system, but is instead a reference to
  # environment information on a remote system. For instance when a catalog is
  # being applied, this will be used on the agent.
  #
  # @note This does not provide access to the information of the remote
  # environment's modules, manifest, or anything else. It is simply a value
  # object to pass around and use as an environment.
  #
  # @param name [Symbol] The name of the remote environment
  #
  def self.remote(name)
    create(name, [], NO_MANIFEST)
  end

  # Instantiate a new environment
  #
  # @note {Puppet::Node::Environment.new} is overridden to return memoized
  #   objects, so this will not be invoked with the normal Ruby initialization
  #   semantics.
  #
  # @param name [Symbol] The environment name
  def initialize(name, modulepath, manifest, config_version)
    @name = name
    @modulepath = modulepath
    @manifest = manifest
    @config_version = config_version
    # set watching to true for legacy environments - the directory based environment loaders will set this to
    # false for directory based environments after the environment has been created.
    @watching = true
  end

  # Returns if files are being watched or not.
  # @api private
  #
  def watching?
    @watching
  end

  # Turns watching of files on or off
  # @param flag [TrueClass, FalseClass] if files should be watched or not
  # @ api private
  def watching=(flag)
    @watching = flag
  end

  # Creates a new Puppet::Node::Environment instance, overriding any of the passed
  # parameters.
  #
  # @param env_params [Hash<{Symbol => String,Array<String>}>] new environment
  #   parameters (:modulepath, :manifest, :config_version)
  # @return [Puppet::Node::Environment]
  def override_with(env_params)
    return self.class.create(name,
                      env_params[:modulepath] || modulepath,
                      env_params[:manifest] || manifest,
                      env_params[:config_version] || config_version)
  end

  # Creates a new Puppet::Node::Environment instance, overriding manfiest
  # modulepath, or :config_version from the passed settings if they were
  # originally set from the commandline, or returns self if there is nothing to
  # override.
  #
  # @param settings [Puppet::Settings] an initialized puppet settings instance
  # @return [Puppet::Node::Environment] new overridden environment or self if
  #   there are no commandline changes from settings.
  def override_from_commandline(settings)
    overrides = {}

    if settings.set_by_cli?(:modulepath)
      overrides[:modulepath] = self.class.split_path(settings.value(:modulepath))
    end

    if settings.set_by_cli?(:config_version)
      overrides[:config_version] = settings.value(:config_version)
    end

    if settings.set_by_cli?(:manifest) ||
      (settings.set_by_cli?(:manifestdir) && settings.value(:manifest).start_with?(settings.value(:manifestdir)))
      overrides[:manifest] = settings.value(:manifest)
    end

    overrides.empty? ?
      self :
      self.override_with(overrides)
  end

  # Retrieve the environment for the current process.
  #
  # @note This should only used when a catalog is being compiled.
  #
  # @api private
  #
  # @return [Puppet::Node::Environment] the currently set environment if one
  #   has been explicitly set, else it will return the '*root*' environment
  def self.current
    Puppet.deprecation_warning("Puppet::Node::Environment.current has been replaced by Puppet.lookup(:current_environment), see http://links.puppetlabs.com/current-env-deprecation")
    Puppet.lookup(:current_environment)
  end

  # @param [String] name Environment name to check for valid syntax.
  # @return [Boolean] true if name is valid
  # @api public
  def self.valid_name?(name)
    !!name.match(/\A\w+\Z/)
  end

  # Clear all memoized environments and the 'current' environment
  #
  # @api private
  def self.clear
    seen.clear
  end

  # @!attribute [r] name
  #   @api public
  #   @return [Symbol] the human readable environment name that serves as the
  #     environment identifier
  attr_reader :name

  # @api public
  # @return [Array<String>] All directories present on disk in the modulepath
  def modulepath
    @modulepath.find_all do |p|
      Puppet::FileSystem.directory?(p)
    end
  end

  # @api public
  # @return [Array<String>] All directories in the modulepath (even if they are not present on disk)
  def full_modulepath
    @modulepath
  end

  # @!attribute [r] manifest
  #   @api public
  #   @return [String] path to the manifest file or directory.
  attr_reader :manifest

  # @!attribute [r] config_version
  #   @api public
  #   @return [String] path to a script whose output will be added to report logs
  #     (optional)
  attr_reader :config_version

  # Checks to make sure that this environment did not have a manifest set in
  # its original environment.conf if Puppet is configured with
  # +disable_per_environment_manifest+ set true.  If it did, the environment's
  # modules may not function as intended by the original authors, and we may
  # seek to halt a puppet compilation for a node in this environment.
  #
  # The only exception to this would be if the environment.conf manifest is an exact,
  # uninterpolated match for the current +default_manifest+ setting.
  #
  # @return [Boolean] true if using directory environments, and
  #   Puppet[:disable_per_environment_manifest] is true, and this environment's
  #   original environment.conf had a manifest setting that is not the
  #   Puppet[:default_manifest].
  # @api public
  def conflicting_manifest_settings?
    return false if Puppet[:environmentpath].empty? || !Puppet[:disable_per_environment_manifest]
    environment_conf = Puppet.lookup(:environments).get_conf(name)
    original_manifest = environment_conf.raw_setting(:manifest)
    !original_manifest.nil? && !original_manifest.empty? && original_manifest != Puppet[:default_manifest]
  end

  # Return an environment-specific Puppet setting.
  #
  # @api public
  #
  # @param param [String, Symbol] The environment setting to look up
  # @return [Object] The resolved setting value
  def [](param)
    Puppet.settings.value(param, self.name)
  end

  # @api public
  # @return [Puppet::Resource::TypeCollection] The current global TypeCollection
  def known_resource_types
    if @known_resource_types.nil?
      @known_resource_types = Puppet::Resource::TypeCollection.new(self)
      @known_resource_types.import_ast(perform_initial_import(), '')
    end
    @known_resource_types
  end

  # Yields each modules' plugin directory if the plugin directory (modulename/lib)
  # is present on the filesystem.
  #
  # @yield [String] Yields the plugin directory from each module to the block.
  # @api public
  def each_plugin_directory(&block)
    modules.map(&:plugin_directory).each do |lib|
      lib = Puppet::Util::Autoload.cleanpath(lib)
      yield lib if File.directory?(lib)
    end
  end

  # Locate a module instance by the module name alone.
  #
  # @api public
  #
  # @param name [String] The module name
  # @return [Puppet::Module, nil] The module if found, else nil
  def module(name)
    modules.find {|mod| mod.name == name}
  end

  # Locate a module instance by the full forge name (EG authorname/module)
  #
  # @api public
  #
  # @param forge_name [String] The module name
  # @return [Puppet::Module, nil] The module if found, else nil
  def module_by_forge_name(forge_name)
    author, modname = forge_name.split('/')
    found_mod = self.module(modname)
    found_mod and found_mod.forge_name == forge_name ?
      found_mod :
      nil
  end

  # @!attribute [r] modules
  #   Return all modules for this environment in the order they appear in the
  #   modulepath.
  #   @note If multiple modules with the same name are present they will
  #     both be added, but methods like {#module} and {#module_by_forge_name}
  #     will return the first matching entry in this list.
  #   @note This value is cached so that the filesystem doesn't have to be
  #     re-enumerated every time this method is invoked, since that
  #     enumeration could be a costly operation and this method is called
  #     frequently. The cache expiry is determined by `Puppet[:filetimeout]`.
  #   @see Puppet::Util::Cacher.cached_attr
  #   @api public
  #   @return [Array<Puppet::Module>] All modules for this environment
  cached_attr(:modules, Puppet[:filetimeout]) do
    module_references = []
    seen_modules = {}
    modulepath.each do |path|
      Dir.entries(path).each do |name|
        warn_about_mistaken_path(path, name)
        next if module_references.include?(name)
        if not seen_modules[name]
          module_references << {:name => name, :path => File.join(path, name)}
          seen_modules[name] = true
        end
      end
    end

    module_references.collect do |reference|
      begin
        Puppet::Module.new(reference[:name], reference[:path], self)
      rescue Puppet::Module::Error
        nil
      end
    end.compact
  end

  # Generate a warning if the given directory in a module path entry is named `lib`.
  #
  # @api private
  #
  # @param path [String] The module directory containing the given directory
  # @param name [String] The directory name
  def warn_about_mistaken_path(path, name)
    if name == "lib"
      Puppet.debug("Warning: Found directory named 'lib' in module path ('#{path}/lib'); unless " +
          "you are expecting to load a module named 'lib', your module path may be set " +
          "incorrectly.")
    end
  end

  # Modules broken out by directory in the modulepath
  #
  # @note This method _changes_ the current working directory while enumerating
  #   the modules. This seems rather dangerous.
  #
  # @api public
  #
  # @return [Hash<String, Array<Puppet::Module>>] A hash whose keys are file
  #   paths, and whose values is an array of Puppet Modules for that path
  def modules_by_path
    modules_by_path = {}
    modulepath.each do |path|
      Dir.chdir(path) do
        module_names = Dir.glob('*').select do |d|
          FileTest.directory?(d) && (File.basename(d) =~ /\A\w+(-\w+)*\Z/)
        end
        modules_by_path[path] = module_names.sort.map do |name|
          Puppet::Module.new(name, File.join(path, name), self)
        end
      end
    end
    modules_by_path
  end

  # All module requirements for all modules in the environment modulepath
  #
  # @api public
  #
  # @comment This has nothing to do with an environment. It seems like it was
  #   stuffed into the first convenient class that vaguely involved modules.
  #
  # @example
  #   environment.module_requirements
  #   # => {
  #   #   'username/amodule' => [
  #   #     {
  #   #       'name'    => 'username/moduledep',
  #   #       'version' => '1.2.3',
  #   #       'version_requirement' => '>= 1.0.0',
  #   #     },
  #   #     {
  #   #       'name'    => 'username/anotherdep',
  #   #       'version' => '4.5.6',
  #   #       'version_requirement' => '>= 3.0.0',
  #   #     }
  #   #   ]
  #   # }
  #   #
  #
  # @return [Hash<String, Array<Hash<String, String>>>] See the method example
  #   for an explanation of the return value.
  def module_requirements
    deps = {}

    modules.each do |mod|
      next unless mod.forge_name
      deps[mod.forge_name] ||= []

      mod.dependencies and mod.dependencies.each do |mod_dep|
        dep_name = mod_dep['name'].tr('-', '/')
        (deps[dep_name] ||= []) << {
          'name'                => mod.forge_name,
          'version'             => mod.version,
          'version_requirement' => mod_dep['version_requirement']
        }
      end
    end

    deps.each do |mod, mod_deps|
      deps[mod] = mod_deps.sort_by { |d| d['name'] }
    end

    deps
  end

  # Set a periodic watcher on the file, so we can tell if it has changed.
  # If watching has been turned off, this call has no effect.
  # @param file[File,String] File instance or filename
  # @api private
  def watch_file(file)
    if watching?
      known_resource_types.watch_file(file.to_s)
    end
  end

  # Checks if a reparse is required (cache of files is stale).
  # This call does nothing unless files are being watched.
  #
  def check_for_reparse
    if (Puppet[:code] != @parsed_code) || (watching? && @known_resource_types && @known_resource_types.require_reparse?)
      @parsed_code = nil
      @known_resource_types = nil
    end
  end

  # @return [String] The stringified value of the `name` instance variable
  # @api public
  def to_s
    name.to_s
  end

  # @return [Symbol] The `name` value, cast to a string, then cast to a symbol.
  #
  # @api public
  #
  # @note the `name` instance variable is a Symbol, but this casts the value
  #   to a String and then converts it back into a Symbol which will needlessly
  #   create an object that needs to be garbage collected
  def to_sym
    to_s.to_sym
  end

  # Return only the environment name when serializing.
  #
  # The only thing we care about when serializing an environment is its
  # identity; everything else is ephemeral and should not be stored or
  # transmitted.
  #
  # @api public
  def to_zaml(z)
    self.to_s.to_zaml(z)
  end

  def self.split_path(path_string)
    path_string.split(File::PATH_SEPARATOR)
  end

  def ==(other)
    return true if other.kind_of?(Puppet::Node::Environment) &&
      self.name == other.name &&
      self.full_modulepath == other.full_modulepath &&
      self.manifest == other.manifest
  end

  alias eql? ==

  def hash
    [self.class, name, full_modulepath, manifest].hash
  end

  private

  def self.extralibs()
    if ENV["PUPPETLIB"]
      split_path(ENV["PUPPETLIB"])
    else
      []
    end
  end

  def self.expand_dirs(dirs)
    dirs.collect do |dir|
      File.expand_path(dir)
    end
  end

  # Reparse the manifests for the given environment
  #
  # There are two sources that can be used for the initial parse:
  #
  #   1. The value of `Puppet.settings[:code]`: Puppet can take a string from
  #     its settings and parse that as a manifest. This is used by various
  #     Puppet applications to read in a manifest and pass it to the
  #     environment as a side effect. This is attempted first.
  #   2. The contents of `Puppet.settings[:manifest]`: Puppet will try to load
  #     the environment manifest. By default this is `$manifestdir/site.pp`
  #
  # @note This method will return an empty hostclass if
  #   `Puppet.settings[:ignoreimport]` is set to true.
  #
  # @return [Puppet::Parser::AST::Hostclass] The AST hostclass object
  #   representing the 'main' hostclass
  def perform_initial_import
    return empty_parse_result if Puppet[:ignoreimport]
    parser = Puppet::Parser::ParserFactory.parser(self)
    @parsed_code = Puppet[:code]
    if @parsed_code != ""
      parser.string = @parsed_code
      parser.parse
    else
      file = self.manifest
      # if the manifest file is a reference to a directory, parse and combine all .pp files in that
      # directory
      if file == NO_MANIFEST
        Puppet::Parser::AST::Hostclass.new('')
      elsif File.directory?(file)
        if Puppet.future_parser?
          parse_results = Puppet::FileSystem::PathPattern.absolute(File.join(file, '**/*.pp')).glob.sort.map do | file_to_parse |
            parser.file = file_to_parse
            parser.parse
          end
        else
          parse_results = Dir.entries(file).find_all { |f| f =~ /\.pp$/ }.sort.map do |file_to_parse|
            parser.file = File.join(file, file_to_parse)
            parser.parse
          end
        end
        # Use a parser type specific merger to concatenate the results
        Puppet::Parser::AST::Hostclass.new('', :code => Puppet::Parser::ParserFactory.code_merger.concatenate(parse_results))
      else
        parser.file = file
        parser.parse
      end
    end
  rescue => detail
    @known_resource_types.parse_failed = true

    msg = "Could not parse for environment #{self}: #{detail}"
    error = Puppet::Error.new(msg)
    error.set_backtrace(detail.backtrace)
    raise error
  end

  # Return an empty toplevel hostclass to indicate that no file was loaded
  #
  # This is used as the return value of {#perform_initial_import} when
  # `Puppet.settings[:ignoreimport]` is true.
  #
  # @return [Puppet::Parser::AST::Hostclass]
  def empty_parse_result
    return Puppet::Parser::AST::Hostclass.new('')
  end

  # A special "null" environment
  #
  # This environment should be used when there is no specific environment in
  # effect.
  NONE = create(:none, [])
end
