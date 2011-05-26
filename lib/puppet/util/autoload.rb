require 'puppet/util/warnings'
require 'puppet/util/cacher'

# Autoload paths, either based on names or all at once.
class Puppet::Util::Autoload
  require 'puppet/util/autoload/file_cache'

  include Puppet::Util
  include Puppet::Util::Warnings
  include Puppet::Util::Cacher
  include Puppet::Util::Autoload::FileCache

  @autoloaders = {}
  @loaded = []

  class << self
    attr_reader :autoloaders
    private :autoloaders
  end

  # Send [], []=, and :clear to the @autloaders hash
  Puppet::Util.classproxy self, :autoloaders, "[]", "[]="

  # List all loaded files.
  def self.list_loaded
    @loaded.sort { |a,b| a[0] <=> b[0] }.collect do |path, hash|
      "#{path}: #{hash[:file]}"
    end
  end

  # Has a given path been loaded?  This is used for testing whether a
  # changed file should be loaded or just ignored.  This is only
  # used in network/client/master, when downloading plugins, to
  # see if a given plugin is currently loaded and thus should be
  # reloaded.
  def self.loaded?(path)
    path = path.to_s.sub(/\.rb$/, '')
    @loaded.include?(path)
  end

  # Save the fact that a given path has been loaded.  This is so
  # we can load downloaded plugins if they've already been loaded
  # into memory.
  def self.loaded(file)
    $" << file + ".rb" unless $".include?(file)
    @loaded << file unless @loaded.include?(file)
  end

  attr_accessor :object, :path, :objwarn, :wrap

  def initialize(obj, path, options = {})
    @path = path.to_s
    raise ArgumentError, "Autoload paths cannot be fully qualified" if @path !~ /^\w/
    @object = obj

    self.class[obj] = self

    options.each do |opt, value|
      opt = opt.intern if opt.is_a? String
      begin
        self.send(opt.to_s + "=", value)
      rescue NoMethodError
        raise ArgumentError, "#{opt} is not a valid option"
      end
    end

    @wrap = true unless defined?(@wrap)
  end

  # Load a single plugin by name.  We use 'load' here so we can reload a
  # given plugin.
  def load(name,env=nil)
    path = name.to_s + ".rb"

    searchpath(env).each do |dir|
      file = File.join(dir, path)
      next unless file_exist?(file)
      begin
        Kernel.load file, @wrap
        name = symbolize(name)
        loaded name, file
        return true
      rescue SystemExit,NoMemoryError
        raise
      rescue Exception => detail
        puts detail.backtrace if Puppet[:trace]
        raise Puppet::Error, "Could not autoload #{name}: #{detail}"
      end
    end
    false
  end

  # Mark the named object as loaded.  Note that this supports unqualified
  # queries, while we store the result as a qualified query in the class.
  def loaded(name, file)
    self.class.loaded(File.join(@path, name.to_s))
  end

  # Indicate whether the specfied plugin has been loaded.
  def loaded?(name)
    self.class.loaded?(File.join(@path, name.to_s))
  end

  # Load all instances that we can.  This uses require, rather than load,
  # so that already-loaded files don't get reloaded unnecessarily.
  def loadall
    # Load every instance of everything we can find.
    files_to_load.each do |file|
      name = File.basename(file).chomp(".rb").intern
      next if loaded?(name)
      begin
        Kernel.require file
        loaded(name, file)
      rescue SystemExit,NoMemoryError
        raise
      rescue Exception => detail
        puts detail.backtrace if Puppet[:trace]
        raise Puppet::Error, "Could not autoload #{file}: #{detail}"
      end
    end
  end

  def files_to_load
    searchpath.map { |dir| Dir.glob("#{dir}/*.rb") }.flatten
  end

  # The list of directories to search through for loadable plugins.
  def searchpath(env=nil)
    search_directories(env).uniq.collect { |d| File.join(d, @path) }.find_all { |d| FileTest.directory?(d) }
  end

  def module_directories(env=nil)
    # We have to require this late in the process because otherwise we might have
    # load order issues.
    require 'puppet/node/environment'

    real_env = Puppet::Node::Environment.new(env)

    # We're using a per-thread cache of said module directories, so that
    # we don't scan the filesystem each time we try to load something with
    # this autoload instance. But since we don't want to cache for the eternity
    # this env_module_directories gets reset after the compilation on the master.
    # This is also reset after an agent ran.
    # One of the side effect of this change is that this module directories list will be
    # shared among all autoload that we have running at a time. But that won't be an issue
    # as by definition those directories are shared by all autoload.
    Thread.current[:env_module_directories] ||= {}
    Thread.current[:env_module_directories][real_env] ||= real_env.modulepath.collect do |dir|
        Dir.entries(dir).reject { |f| f =~ /^\./ }.collect { |f| File.join(dir, f) }
      end.flatten.collect { |d| [File.join(d, "plugins"), File.join(d, "lib")] }.flatten.find_all do |d|
        FileTest.directory?(d)
      end
  end

  def search_directories(env=nil)
    [module_directories(env), Puppet[:libdir].split(File::PATH_SEPARATOR), $LOAD_PATH].flatten
  end
end
