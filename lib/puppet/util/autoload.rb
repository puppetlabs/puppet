require 'pathname'
require 'puppet/util/warnings'

# Autoload paths, either based on names or all at once.
class Puppet::Util::Autoload
  require 'puppet/util/autoload/file_cache'

  include Puppet::Util
  include Puppet::Util::Warnings
  include Puppet::Util::Autoload::FileCache

  @autoloaders = {}
  @loaded = []

  class << self
    attr_reader :autoloaders, :loaded
    private :autoloaders, :loaded

    # List all loaded files.
    def list_loaded
      @loaded.sort { |a,b| a[0] <=> b[0] }.collect do |path, hash|
        "#{path}: #{hash[:file]}"
      end
    end

    # Has a given path been loaded?  This is used for testing whether a
    # changed file should be loaded or just ignored.  This is only
    # used in network/client/master, when downloading plugins, to
    # see if a given plugin is currently loaded and thus should be
    # reloaded.
    def loaded?(path)
      path = path.to_s.sub(/\.rb$/, '')
      @loaded.include?(path)
    end

    # Save the fact that a given path has been loaded.  This is so
    # we can load downloaded plugins if they've already been loaded
    # into memory.
    def mark_loaded(file)
      $" << file + ".rb" unless $".include?(file)
      @loaded << file unless @loaded.include?(file)
    end

    # Load a single plugin by name.  We use 'load' here so we can reload a
    # given plugin.
    def load_file(name, env=nil)
      path = name.to_s + ".rb"

      dirname, base = File.split(path)
      searchpath(dirname, env).each do |dir|
        file = File.join(dir, base)
        next unless File.exist?(file)
        begin
          Kernel.load file, @wrap
          mark_loaded(name)
          return true
        rescue SystemExit,NoMemoryError
          raise
        rescue Exception => detail
          message = "Could not autoload #{name}: #{detail}"
          Puppet.log_exception(detail, message)
          raise Puppet::Error, message
        end
      end
      false
    end

    def loadall(path)
      # Load every instance of everything we can find.
      files_to_load(path).each do |file|
        name = file.chomp(".rb")
        load_file(name) unless loaded?(name)
      end
    end

    def files_to_load(path)
      search_directories.map {|dir| files_in_dir(dir, path) }.flatten.uniq
    end

    def files_in_dir(dir, path)
      dir = Pathname.new(dir)
      Dir.glob(File.join(dir, path, "*.rb")).collect do |file|
        Pathname.new(file).relative_path_from(dir).to_s
      end
    end

    def searchpath(path, env=nil)
      search_directories(env).uniq.collect { |d| File.join(d, path) }.find_all { |d| FileTest.directory?(d) }
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

  # Send [], []=, and :clear to the @autloaders hash
  Puppet::Util.classproxy self, :autoloaders, "[]", "[]="

  attr_accessor :object, :path, :objwarn, :wrap

  def initialize(obj, path, options = {})
    @path = path.to_s
    raise ArgumentError, "Autoload paths cannot be fully qualified" if @path !~ /^\w/
    @object = obj

    self.class[obj] = self

    options.each do |opt, value|
      begin
        self.send(opt.to_s + "=", value)
      rescue NoMethodError
        raise ArgumentError, "#{opt} is not a valid option"
      end
    end

    @wrap = true unless defined?(@wrap)
  end

  def load(name, env=nil)
    self.class.load_file(File.join(@path, name.to_s), env)
  end

  # Load all instances that we can.  This uses require, rather than load,
  # so that already-loaded files don't get reloaded unnecessarily.
  def loadall
    self.class.loadall(@path)
  end

  def files_to_load
    self.class.files_to_load(@path)
  end

  # The list of directories to search through for loadable plugins.
  def searchpath(env=nil)
    self.class.searchpath(@path, env)
  end
end
