require 'pathname'
require 'puppet/util/rubygems'
require 'puppet/util/warnings'
require 'puppet/util/methodhelper'
require 'puppet/pops/adaptable'

# An adapter that ties the module_directories cache to the environment where the modules are parsed. This
# adapter ensures that the life-cycle of this cache doesn't exceed  the life-cycle of the environment.
#
# @api private
class Puppet::Util::ModuleDirectoriesAdapter < Puppet::Pops::Adaptable::Adapter
  attr_accessor :directories
end

# Autoload paths, either based on names or all at once.
class Puppet::Util::Autoload
  include Puppet::Util::MethodHelper

  @loaded = {}

  class << self
    attr_accessor :loaded

    def gem_source
      @gem_source ||= Puppet::Util::RubyGems::Source.new
    end

    # Has a given path been loaded?  This is used for testing whether a
    # changed file should be loaded or just ignored.  This is only
    # used in network/client/master, when downloading plugins, to
    # see if a given plugin is currently loaded and thus should be
    # reloaded.
    def loaded?(path)
      path = cleanpath(path).chomp('.rb')
      loaded.include?(path)
    end

    # Save the fact that a given path has been loaded.  This is so
    # we can load downloaded plugins if they've already been loaded
    # into memory.
    def mark_loaded(name, file)
      name = cleanpath(name).chomp('.rb')
      ruby_file = name + ".rb"
      $LOADED_FEATURES << ruby_file unless $LOADED_FEATURES.include?(ruby_file)
      loaded[name] = [file, File.mtime(file)]
    end

    def changed?(name)
      name = cleanpath(name).chomp('.rb')
      return true unless loaded.include?(name)
      file, old_mtime = loaded[name]
      environment = Puppet.lookup(:current_environment)
      return true unless file == get_file(name, environment)
      begin
        old_mtime.to_i != File.mtime(file).to_i
      rescue Errno::ENOENT
        true
      end
    end

    # Load a single plugin by name.  We use 'load' here so we can reload a
    # given plugin.
    def load_file(name, env)
      file = get_file(name.to_s, env)
      return false unless file
      begin
        mark_loaded(name, file)
        Kernel.load file
        return true
      rescue SystemExit,NoMemoryError
        raise
      rescue Exception => detail
        message = "Could not autoload #{name}: #{detail}"
        Puppet.log_exception(detail, message)
        raise Puppet::Error, message, detail.backtrace
      end
    end

    def loadall(path, env = nil)
      # Load every instance of everything we can find.
      files_to_load(path, env).each do |file|
        name = file.chomp(".rb")
        load_file(name, env) unless loaded?(name)
      end
    end

    def reload_changed
      loaded.keys.each { |file| load_file(file, nil) if changed?(file) }
    end

    # Get the correct file to load for a given path
    # returns nil if no file is found
    def get_file(name, env)
      name = name + '.rb' unless name =~ /\.rb$/
      path = search_directories(env).find { |dir| Puppet::FileSystem.exist?(File.join(dir, name)) }
      path and File.join(path, name)
    end

    def files_to_load(path, env = nil)
      search_directories(env).map {|dir| files_in_dir(dir, path) }.flatten.uniq
    end

    def files_in_dir(dir, path)
      dir = Pathname.new(File.expand_path(dir))
      Dir.glob(File.join(dir, path, "*.rb")).collect do |file|
        Pathname.new(file).relative_path_from(dir).to_s
      end
    end

    def module_directories(env)
      # This is a little bit of a hack.  Basically, the autoloader is being
      # called indirectly during application bootstrapping when we do things
      # such as check "features".  However, during bootstrapping, we haven't
      # yet parsed all of the command line parameters nor the config files,
      # and thus we don't yet know with certainty what the module path is.
      # This should be irrelevant during bootstrapping, because anything that
      # we are attempting to load during bootstrapping should be something
      # that we ship with puppet, and thus the module path is irrelevant.
      #
      # In the long term, I think the way that we want to handle this is to
      # have the autoloader ignore the module path in all cases where it is
      # not specifically requested (e.g., by a constructor param or
      # something)... because there are very few cases where we should
      # actually be loading code from the module path.  However, until that
      # happens, we at least need a way to prevent the autoloader from
      # attempting to access the module path before it is initialized.  For
      # now we are accomplishing that by calling the
      # "app_defaults_initialized?" method on the main puppet Settings object.
      # --cprice 2012-03-16
      if Puppet.settings.app_defaults_initialized?
        env ||= Puppet.lookup(:environments).get(Puppet[:environment])

        if env
          # if the app defaults have been initialized then it should be safe to access the module path setting.
          Puppet::Util::ModuleDirectoriesAdapter.adapt(env) do |a|
            a.directories ||= env.modulepath.collect do |dir|
              Dir.entries(dir).reject { |f| f =~ /^\./ }.collect { |f| File.join(dir, f, "lib") }
            end.flatten.find_all do |d|
              FileTest.directory?(d)
            end
          end.directories
        else
          []
        end
      else
        # if we get here, the app defaults have not been initialized, so we basically use an empty module path.
        []
      end
    end

    def libdirs()
      # See the comments in #module_directories above.  Basically, we need to be careful not to try to access the
      # libdir before we know for sure that all of the settings have been initialized (e.g., during bootstrapping).
      if (Puppet.settings.app_defaults_initialized?)
        [Puppet[:libdir]]
      else
        []
      end
    end

    def gem_directories
      gem_source.directories
    end

    def search_directories(env)
      [gem_directories, module_directories(env), libdirs(), $LOAD_PATH].flatten
    end

    # Normalize a path. This converts ALT_SEPARATOR to SEPARATOR on Windows
    # and eliminates unnecessary parts of a path.
    def cleanpath(path)
      # There are two cases here because cleanpath does not handle absolute
      # paths correctly on windows (c:\ and c:/ are treated as distinct) but
      # we don't want to convert relative paths to absolute
      if Puppet::Util.absolute_path?(path)
        File.expand_path(path)
      else
        Pathname.new(path).cleanpath.to_s
      end
    end
  end

  attr_accessor :object, :path

  def initialize(obj, path, options = {})
    @path = path.to_s
    raise ArgumentError, "Autoload paths cannot be fully qualified" if Puppet::Util.absolute_path?(@path)
    @object = obj

    set_options(options)
  end

  def load(name, env = nil)
    self.class.load_file(expand(name), env)
  end

  # Load all instances from a path of Autoload.search_directories matching the
  # relative path this Autoloader was initialized with.  For example, if we
  # have created a Puppet::Util::Autoload for Puppet::Type::User with a path of
  # 'puppet/provider/user', the search_directories path will be searched for
  # all ruby files matching puppet/provider/user/*.rb and they will then be
  # loaded from the first directory in the search path providing them.  So
  # earlier entries in the search path may shadow later entries.
  #
  # This uses require, rather than load, so that already-loaded files don't get
  # reloaded unnecessarily.
  def loadall(env = nil)
    self.class.loadall(@path, env)
  end

  def loaded?(name)
    self.class.loaded?(expand(name))
  end

  def changed?(name)
    self.class.changed?(expand(name))
  end

  def files_to_load
    self.class.files_to_load(@path)
  end

  def expand(name)
    ::File.join(@path, name.to_s)
  end
end
