module Puppet::Pops
module Loader
# =ModuleLoaders
# A ModuleLoader loads items from a single module.
# The ModuleLoaders (ruby) module contains various such loaders. There is currently one concrete
# implementation, ModuleLoaders::FileBased that loads content from the file system.
# Other implementations can be created - if they are based on name to path mapping where the path
# is relative to a root path, they can derive the base behavior from the ModuleLoaders::AbstractPathBasedModuleLoader class.
#
# Examples of such extensions could be a zip/jar/compressed file base loader.
#
# Notably, a ModuleLoader does not configure itself - it is given the information it needs (the root, its name etc.)
# Logic higher up in the loader hierarchy of things makes decisions based on the "shape of modules", and "available
# modules" to determine which module loader to use for each individual module. (There could be differences in
# internal layout etc.)
#
# A module loader is also not aware of the mapping of name to relative paths - this is performed by the
# included module PathBasedInstantatorConfig which knows about the map from type/name to
# relative path, and the logic that can instantiate what is expected to be found in the content of that path.
#
# @api private
#
module ModuleLoaders
  def self.system_loader_from(parent_loader, loaders)
    # Puppet system may be installed in a fixed location via RPM, installed as a Gem, via source etc.
    # The only way to find this across the different ways puppet can be installed is
    # to search up the path from this source file's __FILE__ location until it finds the base of
    # puppet.
    #
    puppet_lib = File.join(File.dirname(__FILE__), '../../..')
    ModuleLoaders::FileBased.new(parent_loader,
                                                       loaders,
                                                       nil,
                                                       puppet_lib,   # may or may not have a 'lib' above 'puppet'
                                                       'puppet_system',
                                                        [:func_4x]   # only load ruby functions from "puppet"
                                                       )
  end

  def self.module_loader_from(parent_loader, loaders, module_name, module_path)
    ModuleLoaders::FileBased.new(parent_loader,
                                                       loaders,
                                                       module_name,
                                                       File.join(module_path, 'lib'),
                                                       module_name
                                                       )
  end

  class AbstractPathBasedModuleLoader < BaseLoader

    # The name of the module, or nil, if this is a global "component"
    attr_reader :module_name

    # The path to the location of the module/component - semantics determined by subclass
    attr_reader :path

    # A map of type to smart-paths that help with minimizing the number of paths to scan
    attr_reader :smart_paths

    # A Module Loader has a private loader, it is lazily obtained on request to provide the visibility
    # for entities contained in the module. Since a ModuleLoader also represents an environment and it is
    # created a different way, this loader can be set explicitly by the loaders bootstrap logic.
    #
    # @api private
    attr_accessor :private_loader

    # Initialize a kind of ModuleLoader for one module
    # @param parent_loader [Loader] loader with higher priority
    # @param module_name [String] the name of the module (non qualified name), may be nil for a global "component"
    # @param path [String] the path to the root of the module (semantics defined by subclass)
    # @param loader_name [String] a name that is used for human identification (useful when module_name is nil)
    #
    def initialize(parent_loader, loaders, module_name, path, loader_name, loadables)
      super parent_loader, loader_name

      @module_name = module_name
      @path = path
      @smart_paths = LoaderPaths::SmartPaths.new(self)
      @loaders = loaders
      @loadables = loadables
      unless (loadables - LOADABLE_KINDS).empty?
        raise ArgumentError, 'given loadables are not of supported loadable kind'
      end
    end

    def loadables
      @loadables
    end

    # Finds typed/named entity in this module
    # @param typed_name [TypedName] the type/name to find
    # @return [Loader::NamedEntry, nil found/created entry, or nil if not found
    #
    def find(typed_name)
      # Assume it is a global name, and that all parts of the name should be used when looking up
      name_part_index = 0
      name_parts = typed_name.name_parts

      # Certain types and names can be disqualified up front
      if name_parts.size > 1
        # The name is in a name space.

        # Then entity cannot possible be in this module unless the name starts with the module name.
        # Note: If "module" represents a "global component", the module_name is nil and cannot match which is
        # ok since such a "module" cannot have namespaced content).
        #
        return nil unless name_parts[0] == module_name

        # Skip the first part of the name when computing the path since the path already contains the name of the
        # module
        name_part_index = 1
      else
        # The name is in the global name space.

        # The only globally name-spaced elements that may be loaded from modules are functions and resource types
        case typed_name.type
        when :function
        when :resource_type
        when :type
        else
          # anything else cannot possibly be in this module
          # TODO: should not be allowed anyway... may have to revisit this decision
          return nil
        end
      end

      # Get the paths that actually exist in this module (they are lazily processed once and cached).
      # The result is an array (that may be empty).
      # Find the file to instantiate, and instantiate the entity if file is found
      origin = nil
      if (smart_path = smart_paths.effective_paths(typed_name.type).find do |sp|
          origin = sp.effective_path(typed_name, name_part_index)
          existing_path(origin)
        end)
        value = smart_path.instantiator.create(self, typed_name, origin, get_contents(origin))
        # cache the entry and return it
        set_entry(typed_name, value, origin)
      else
        nil
      end
    end

    # Abstract method that subclasses override that checks if it is meaningful to search using a generic smart path.
    # This optimization is performed to not be tricked into searching an empty directory over and over again.
    # The implementation may perform a deep search for file content other than directories and cache this in
    # and index. It is guaranteed that a call to meaningful_to_search? takes place before checking any other
    # path with relative_path_exists?.
    #
    # This optimization exists because many modules have been created from a template and they have
    # empty directories for functions, types, etc. (It is also the place to create a cached index of the content).
    #
    # @param smart_path [String] a path relative to the module's root
    # @return [Boolean] true if there is content in the directory appointed by the relative path
    #
    def meaningful_to_search?(smart_path)
      raise NotImplementedError.new
    end

    # Abstract method that subclasses override to answer if the given relative path exists, and if so returns that path
    #
    # @param resolved_path [String] a path resolved by a smart path against the loader's root (if it has one)
    # @return [Boolean] true if the file exists
    #
    def existing_path(resolved_path)
      raise NotImplementedError.new
    end

    # Abstract method that subclasses override to produce the content of the effective path.
    # It should either succeed and return a String or fail with an exception.
    #
    # @param effective_path [String] a path as resolved by a smart path
    # @return [String] the content of the file
    #
    def get_contents(effective_path)
      raise NotImplementedError.new
    end

    # Abstract method that subclasses override to produce a source reference String used to identify the
    # system resource (resource in the URI sense).
    #
    # @param relative_path [String] a path relative to the module's root
    # @return [String] a reference to the source file (in file system, zip file, or elsewhere).
    #
    def get_source_ref(relative_path)
      raise NotImplementedError.new
    end

    # Produces the private loader for the module. If this module is not already resolved, this will trigger resolution
    #
    def private_loader
      # The system loader has a nil module_name and it does not have a private_loader as there are no functions
      # that can only by called by puppet runtime - if so, it acts as the private loader directly.
      @private_loader ||= ((module_name.nil? && self) || @loaders.private_loader_for_module(module_name))
    end
  end

  # @api private
  #
  class FileBased < AbstractPathBasedModuleLoader

    attr_reader :smart_paths
    attr_reader :path_index

    # Create a kind of ModuleLoader for one module (Puppet Module, or module like)
    #
    # @param parent_loader [Loader] typically the loader for the environment or root
    # @param module_name [String] the name of the module (non qualified name), may be nil for "modules" only containing globals
    # @param path [String] the path to the root of the module (semantics defined by subclass)
    # @param loader_name [String] a name that identifies the loader
    #
    def initialize(parent_loader, loaders, module_name, path, loader_name, loadables = LOADABLE_KINDS)
      super
      @path_index = Set.new()
    end

    def existing_path(effective_path)
      # Optimized, checks index instead of visiting file system
      @path_index.include?(effective_path) ? effective_path : nil
    end

    def meaningful_to_search?(smart_path)
      ! add_to_index(smart_path).empty?
    end

    def to_s()
      "(ModuleLoader::FileBased '#{loader_name()}' '#{module_name()}')"
    end

    def add_to_index(smart_path)
      found = Dir.glob(File.join(smart_path.generic_path, '**', "*#{smart_path.extension}"))
      @path_index.merge(found)
      found
    end

    def get_contents(effective_path)
      Puppet::FileSystem.read(effective_path, :encoding => 'utf-8')
    end
  end

  # Loads from a gem specified as a URI, gem://gemname/optional/path/in/gem, or just a String gemname.
  # The source reference (shown in errors etc.) is the expanded path of the gem as this is believed to be more
  # helpful - given the location it should be quite obvious which gem it is, without the location, the user would
  # need to go on a hunt for where the file actually is located.
  #
  # TODO: How does this get instantiated? Does the gemname refelect the name of the module (the namespace)
  #   or is that specified a different way? Can a gem be the container of multiple modules?
  #
  # @api private
  #
  class GemBased < FileBased
    include GemSupport

    attr_reader :gem_ref

    # Create a kind of ModuleLoader for one module
    # The parameters are:
    # * parent_loader - typically the loader for the root
    # * module_name - the name of the module (non qualified name)
    # * gem_ref - [URI, String] gem reference to the root of the module (URI, gem://gemname/optional/path/in/gem), or
    #     just the gem's name as a String.
    #
    def initialize(parent_loader, loaders, module_name, gem_ref, loader_name, loadables = LOADABLE_KINDS)
      @gem_ref = gem_ref
      super parent_loader, loaders, module_name, gem_dir(gem_ref), loader_name, loadables
    end

    def to_s()
      "(ModuleLoader::GemBased '#{loader_name()}' '#{@gem_ref}' [#{module_name()}])"
    end
  end
end
end
end
