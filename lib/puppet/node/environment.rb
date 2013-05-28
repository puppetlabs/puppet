require 'puppet/util'
require 'puppet/util/cacher'
require 'monitor'
require 'puppet/parser/parser_factory'

# Just define it, so this class has fewer load dependencies.
class Puppet::Node
end

# Model the environment that a node can operate in.  This class just
# provides a simple wrapper for the functionality around environments.
class Puppet::Node::Environment
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

  @seen = {}

  # Return an existing environment instance, or create a new one.
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

  def self.current
    Thread.current[:environment] || root
  end

  def self.current=(env)
    Thread.current[:environment] = new(env)
  end

  def self.root
    @root
  end

  def self.clear
    @seen.clear
    Thread.current[:environment] = nil
  end

  attr_reader :name

  # Return an environment-specific setting.
  def [](param)
    Puppet.settings.value(param, self.name)
  end

  def initialize(name)
    @name = name
    extend MonitorMixin
  end

  def known_resource_types
    # This makes use of short circuit evaluation to get the right thread-safe
    # per environment semantics with an efficient most common cases; we almost
    # always just return our thread's known-resource types.  Only at the start
    # of a compilation (after our thread var has been set to nil) or when the
    # environment has changed do we delve deeper.
    Thread.current[:known_resource_types] = nil if (krt = Thread.current[:known_resource_types]) && krt.environment != self
    Thread.current[:known_resource_types] ||= synchronize {
      if @known_resource_types.nil? or @known_resource_types.require_reparse?
        @known_resource_types = Puppet::Resource::TypeCollection.new(self)
        @known_resource_types.import_ast(perform_initial_import, '')
      end
      @known_resource_types
    }
  end

  # Yields each modules' plugin directory.
  #
  # @yield [String] Yields the plugin directory from each module to the block.
  # @api public
  def each_plugin_directory(&block)
    modules.map(&:plugin_directory).each do |lib|
      lib = Puppet::Util::Autoload.cleanpath(lib)
      yield lib if File.directory?(lib)
    end
  end

  def module(name)
    modules.find {|mod| mod.name == name}
  end

  def module_by_forge_name(forge_name)
    author, modname = forge_name.split('/')
    found_mod = self.module(modname)
    found_mod and found_mod.forge_name == forge_name ?
      found_mod :
      nil
  end

  # Cache the modulepath, so that we aren't searching through
  # all known directories all the time.
  cached_attr(:modulepath, Puppet[:filetimeout]) do
    dirs = self[:modulepath].split(File::PATH_SEPARATOR)
    dirs = ENV["PUPPETLIB"].split(File::PATH_SEPARATOR) + dirs if ENV["PUPPETLIB"]
    validate_dirs(dirs)
  end

  # Return all modules from this environment, in the order they appear
  # in the modulepath
  # Cache the list, because it can be expensive to create.
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

  def warn_about_mistaken_path(path, name)
    if name == "lib"
      Puppet.debug("Warning: Found directory named 'lib' in module path ('#{path}/lib'); unless " +
          "you are expecting to load a module named 'lib', your module path may be set " +
          "incorrectly.")
    end
  end

  # Modules broken out by directory in the modulepath
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

  def to_s
    name.to_s
  end

  def to_sym
    to_s.to_sym
  end

  # The only thing we care about when serializing an environment is its
  # identity; everything else is ephemeral and should not be stored or
  # transmitted.
  def to_zaml(z)
    self.to_s.to_zaml(z)
  end

  def validate_dirs(dirs)
    dirs.collect do |dir|
      File.expand_path(dir)
    end.find_all do |p|
      FileTest.directory?(p)
    end
  end

  private

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

  def empty_parse_result
    # Return an empty toplevel hostclass to use as the result of
    # perform_initial_import when no file was actually loaded.
    return Puppet::Parser::AST::Hostclass.new('')
  end

  @root = new(:'*root*')
end
