# frozen_string_literal: true

require 'pathname'
require_relative '../../puppet/util/rubygems'
require_relative '../../puppet/util/warnings'
require_relative '../../puppet/pops/adaptable'
require_relative '../../puppet/concurrent/synchronized'

# An adapter that ties the module_directories cache to the environment where the modules are parsed. This
# adapter ensures that the life-cycle of this cache doesn't exceed  the life-cycle of the environment.
#
# @api private
class Puppet::Util::ModuleDirectoriesAdapter < Puppet::Pops::Adaptable::Adapter
  attr_accessor :directories

  def self.create_adapter(env)
    adapter = super(env)
    adapter.directories = env.modulepath.flat_map do |dir|
      Dir.glob(File.join(dir, '*', 'lib'))
    end
    adapter
  end
end

# Autoload paths, either based on names or all at once.
class Puppet::Util::Autoload
  include Puppet::Concurrent::Synchronized
  extend Puppet::Concurrent::Synchronized

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
    # @api private
    def mark_loaded(name, file)
      name = cleanpath(name).chomp('.rb')
      file = File.expand_path(file)
      $LOADED_FEATURES << file unless $LOADED_FEATURES.include?(file)
      loaded[name] = [file, File.mtime(file)]
    end

    # @api private
    def changed?(name, env)
      name = cleanpath(name).chomp('.rb')
      return true unless loaded.include?(name)

      file, old_mtime = loaded[name]
      return true unless file == get_file(name, env)

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
        true
      rescue SystemExit, NoMemoryError
        raise
      rescue Exception => detail
        message = _("Could not autoload %{name}: %{detail}") % { name: name, detail: detail }
        Puppet.log_exception(detail, message)
        raise Puppet::Error, message, detail.backtrace
      end
    end

    def loadall(path, env)
      # Load every instance of everything we can find.
      files_to_load(path, env).each do |file|
        name = file.chomp(".rb")
        load_file(name, env) unless loaded?(name)
      end
    end

    def reload_changed(env)
      loaded.keys.each do |file|
        if changed?(file, env)
          load_file(file, env)
        end
      end
    end

    # Get the correct file to load for a given path
    # returns nil if no file is found
    # @api private
    def get_file(name, env)
      name += '.rb' unless name =~ /\.rb$/
      path = search_directories(env).find { |dir| Puppet::FileSystem.exist?(File.join(dir, name)) }
      path and File.join(path, name)
    end

    def files_to_load(path, env)
      search_directories(env).map { |dir| files_in_dir(dir, path) }.flatten.uniq
    end

    # @api private
    def files_in_dir(dir, path)
      dir = Pathname.new(Puppet::FileSystem.expand_path(dir))
      Dir.glob(File.join(dir, path, "*.rb")).collect do |file|
        Pathname.new(file).relative_path_from(dir).to_s
      end
    end

    # @api private
    def module_directories(env)
      raise ArgumentError, "Autoloader requires an environment" unless env

      Puppet::Util::ModuleDirectoriesAdapter.adapt(env).directories
    end

    # @api private
    def gem_directories
      gem_source.directories
    end

    # @api private
    def search_directories(env)
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
        gem_directories + module_directories(env) + $LOAD_PATH
      else
        gem_directories + $LOAD_PATH
      end
    end

    # Normalize a path. This converts ALT_SEPARATOR to SEPARATOR on Windows
    # and eliminates unnecessary parts of a path.
    def cleanpath(path)
      Pathname.new(path).cleanpath.to_s
    end
  end

  attr_accessor :object, :path

  def initialize(obj, path)
    @path = path.to_s
    raise ArgumentError, _("Autoload paths cannot be fully qualified") if Puppet::Util.absolute_path?(@path)

    @object = obj
  end

  def load(name, env)
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
  def loadall(env)
    self.class.loadall(@path, env)
  end

  def loaded?(name)
    self.class.loaded?(expand(name))
  end

  # @api private
  def changed?(name, env)
    self.class.changed?(expand(name), env)
  end

  def files_to_load(env)
    self.class.files_to_load(@path, env)
  end

  def expand(name)
    ::File.join(@path, name.to_s)
  end
end
