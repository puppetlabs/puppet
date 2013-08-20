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
# ## Global variables
#
# The Puppet::Node::Environment uses a number of global variables.
#
# ### `$environment`
#
# The 'environment' global variable represents the current environment that's
# being used in the compiler.
#
# ### `$known_resource_types`
#
# The 'known_resource_types' global variable represents a singleton instance
# of the Puppet::Resource::TypeCollection class. The variable is discarded
# and regenerated if it is accessed by an environment that doesn't match the
# environment of the 'known_resource_types'
#
# This behavior of discarding the known_resource_types every time the
# environment changes is not ideal. In the best case this can cause valid data
# to be discarded and reloaded. If Puppet is being used with numerous
# environments then this penalty will be repeatedly incurred.
#
# In the worst case (#15106) demonstrates that if a different environment is
# accessed during catalog compilation, for whatever reason, the
# known_resource_types can be discarded which loses information that cannot
# be recovered and can cause a catalog compilation to completely fail.
#
# ## The root environment
#
# In addition to normal environments that are defined by the user,there is a
# special 'root' environment. It is defined as an instance variable on the
# Puppet::Node::Environment metaclass. The environment name is `*root*` and can
# be accessed by calling {Puppet::Node::Environment.root}.
#
# The primary purpose of the root environment is to contain parser functions
# that are not bound to a specific environment. The main case for this is for
# logging functions. Logging functions are attached to the 'root' environment
# when {Puppet::Parser::Functions.reset} is called.
#
# The root environment is also used as a fallback environment when the
# current environment has been requested by {Puppet::Node::Environment.current}
# requested and no environment was set by {Puppet::Node::Environment.current=}
class Puppet::Node::Environment

  # This defines a mixin for classes that have an environment. It implements
  # `environment` and `environment=` that respects the semantics of the
  # Puppet::Node::Environment class
  #
  # @api public
  module Helper

    def environment
      Puppet::Node::Environment.new(@environment)
    end

    def environment=(env)
      if env.is_a?(String) or env.is_a?(Symbol)
        @environment = env
      else
        @environment = env.name
      end
    end
  end

  include Puppet::Util::Cacher

  # @!attribute seen
  #   @scope class
  #   @api private
  #   @return [Hash<Symbol, Puppet::Node::Environment>] All memoized environments
  @seen = {}

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

    return @seen[symbol] if @seen[symbol]

    obj = self.allocate
    obj.send :initialize, symbol
    @seen[symbol] = obj
  end

  # Retrieve the environment for the current thread
  #
  # @note This should only used when a catalog is being compiled.
  #
  # @api private
  #
  # @return [Puppet::Node::Environment] the currently set environment if one
  #   has been explicitly set, else it will return the '*root*' environment
  def self.current
    $environment || root
  end

  # Set the environment for the current thread
  #
  # @note This should only set when a catalog is being compiled. Under normal
  #   This value is initially set in {Puppet::Parser::Compiler#environment}
  #
  # @note Setting this affects global state during catalog compilation, and
  #   changing the current environment during compilation can cause unexpected
  #   and generally very bad behaviors.
  #
  # @api private
  #
  # @param env [Puppet::Node::Environment]
  def self.current=(env)
    $environment = new(env)
  end


  # @return [Puppet::Node::Environment] The `*root*` environment.
  #
  # This is only used for handling functions that are not attached to a
  # specific environment.
  #
  # @api private
  def self.root
    @root
  end

  # Clear all memoized environments and the 'current' environment
  #
  # @api private
  def self.clear
    @seen.clear
    $environment = nil
  end

  # @!attribute [r] name
  #   @api public
  #   @return [Symbol] the human readable environment name that serves as the
  #     environment identifier
  attr_reader :name

  # Return an environment-specific Puppet setting.
  #
  # @api public
  #
  # @param param [String, Symbol] The environment setting to look up
  # @return [Object] The resolved setting value
  def [](param)
    Puppet.settings.value(param, self.name)
  end

  # Instantiate a new environment
  #
  # @note {Puppet::Node::Environment.new} is overridden to return memoized
  #   objects, so this will not be invoked with the normal Ruby initialization
  #   semantics.
  #
  # @param name [Symbol] The environment name
  def initialize(name)
    @name = name
  end

  # The current global TypeCollection
  #
  # @note The environment is loosely coupled with the {Puppet::Resource::TypeCollection}
  #   class. While there is a 1:1 relationship between an environment and a
  #   TypeCollection instance, there is only one TypeCollection instance
  #   available at any given time. It is stored in `$known_resource_types`.
  #   `$known_resource_types` is accessed as an instance method, but is global
  #   to all environment variables.
  #
  # @api public
  # @return [Puppet::Resource::TypeCollection] The current global TypeCollection
  def known_resource_types
    # This makes use of short circuit evaluation to get the right thread-safe
    # per environment semantics with an efficient most common cases; we almost
    # always just return our thread's known-resource types.  Only at the start
    # of a compilation (after our thread var has been set to nil) or when the
    # environment has changed do we delve deeper.
    $known_resource_types = nil if $known_resource_types && $known_resource_types.environment != self
    $known_resource_types ||=
      if @known_resource_types.nil? or @known_resource_types.require_reparse?
        @known_resource_types = Puppet::Resource::TypeCollection.new(self)
        @known_resource_types.import_ast(perform_initial_import, '')
        @known_resource_types
      else
        @known_resource_types
      end
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

  # @!attribute [r] modulepath
  #   Return all existent directories in the modulepath for this environment
  #   @note This value is cached so that the filesystem doesn't have to be
  #     re-enumerated every time this method is invoked, since that
  #     enumeration could be a costly operation and this method is called
  #     frequently. The cache expiry is determined by `Puppet[:filetimeout]`.
  #   @see Puppet::Util::Cacher.cached_attr
  #   @api public
  #   @return [Array<String>] All directories present in the modulepath
  cached_attr(:modulepath, Puppet[:filetimeout]) do
    dirs = self[:modulepath].split(File::PATH_SEPARATOR)
    dirs = ENV["PUPPETLIB"].split(File::PATH_SEPARATOR) + dirs if ENV["PUPPETLIB"]
    validate_dirs(dirs)
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
        deps[mod_dep['name']] ||= []
        dep_details = {
          'name'                => mod.forge_name,
          'version'             => mod.version,
          'version_requirement' => mod_dep['version_requirement']
        }
        deps[mod_dep['name']] << dep_details
      end
    end
    deps.each do |mod, mod_deps|
      deps[mod] = mod_deps.sort_by {|d| d['name']}
    end
    deps
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

  # Validate a list of file paths and return the paths that are directories on the filesystem
  #
  # @api private
  #
  # @param dirs [Array<String>] The file paths to validate
  # @return [Array<String>] All file paths that exist and are directories
  def validate_dirs(dirs)
    dirs.collect do |dir|
      File.expand_path(dir)
    end.find_all do |p|
      FileTest.directory?(p)
    end
  end

  private

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
    return empty_parse_result if Puppet.settings[:ignoreimport]
#    parser = Puppet::Parser::Parser.new(self)
    parser = Puppet::Parser::ParserFactory.parser(self)
    if code = Puppet.settings.uninterpolated_value(:code, name.to_s) and code != ""
      parser.string = code
    else
      file = Puppet.settings.value(:manifest, name.to_s)
      parser.file = file
    end
    parser.parse
  rescue => detail
    known_resource_types.parse_failed = true

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

  @root = new(:'*root*')
end
