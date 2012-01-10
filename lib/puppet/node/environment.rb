require 'puppet/util/cacher'
require 'monitor'

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

  def module(name)
    mod = Puppet::Module.new(name, :environment => self)
    return nil unless mod.exist?
    mod
  end

  # Cache the modulepath, so that we aren't searching through
  # all known directories all the time.
  cached_attr(:modulepath, Puppet[:filetimeout]) do
    dirs = self[:modulepath].split(File::PATH_SEPARATOR)
    dirs = ENV["PUPPETLIB"].split(File::PATH_SEPARATOR) + dirs if ENV["PUPPETLIB"]
    validate_dirs(dirs)
  end

  # Return all modules from this environment.
  # Cache the list, because it can be expensive to create.
  cached_attr(:modules, Puppet[:filetimeout]) do
    module_names = modulepath.collect { |path| Dir.entries(path) }.flatten.uniq
    module_names.collect do |path|
      begin
        Puppet::Module.new(path, :environment => self)
      rescue Puppet::Module::Error => e
        nil
      end
    end.compact
  end

  # Modules broken out by directory in the modulepath
  def modules_by_path
    modules_by_path = {}
    modulepath.each do |path|
      Dir.chdir(path) do
        module_names = Dir.glob('*').select { |d| FileTest.directory? d }
        modules_by_path[path] = module_names.map do |name|
          Puppet::Module.new(name, :environment => self, :path => File.join(path, name))
        end
      end
    end
    modules_by_path
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
    dir_regex = Puppet.features.microsoft_windows? ? /^[A-Za-z]:#{File::SEPARATOR}/ : /^#{File::SEPARATOR}/
    # REMIND: Dir.getwd on windows returns a path containing backslashes, which when joined with
    # dir containing forward slashes, breaks our regex matching. In general, path validation needs
    # to be refactored which will be handled in a future commit.
    dirs.collect do |dir|
      if dir !~ dir_regex
        File.expand_path(File.join(Dir.getwd, dir))
      else
        dir
      end
    end.find_all do |p|
      p =~ dir_regex && FileTest.directory?(p)
    end
  end

  private

  def perform_initial_import
    return empty_parse_result if Puppet.settings[:ignoreimport]
    parser = Puppet::Parser::Parser.new(self)
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
