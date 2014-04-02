require 'puppet/pops/impl/loader/uri_helper'
require 'delegator'

# A ModuleLoaderConfigurator is responsible for configuring module loaders given a module path
# NOTE: Exploratory code (not yet fully featured/functional) showing how a configurator loads and configures
# ModuleLoaders for a given set of modules on a given module path.
# 
# ==Usage
# Create an instance and for each wanted entry call one of the methods #add_all_modules,
# or #add_module. A call must be made to #add_root (once only) to define where the root is.
# 
# The next step is to produce loaders for the modules. This involves resolving the modules dependencies
# to know what is visible to each module (and later to create a real loader). This can be a quite heavy
# operation and there may be many more modules available than what will actually be used.
# The creation of loaders is therefore performed lazily.
#
# A call to #create_loaders sets up lazy loaders for all modules and creates the real loader for
# the root.
#
class ModuleLoaderConfigurator
  include Puppet::Pops::Impl::Loader::UriHelper

  def initialize(modulepath)
    @root_module = nil
    # maps module name to list of ModuleData (different versions of module)
    @module_name_to_data = {}
    @modules = [] # list in search path order
  end

  # =ModuleData
  # Reference to a module's data
  # TODO: should have reference to real model element containing all module data; this is faking it
  #
  class ModuleData
    attr_accessor :name, :version, :state, :loader, :path, :module_element, :resolutions
    def initialize name, version, path
      @name = name
      @version = version
      @path = path
      @state = :unresolved
      @module_element = nil # should be a model element describing the module
      @resolutions = []
      @loader = nil
    end
    def requirements
      nil # FAKE: this says "wants to see everything"
    end
    def is_resolved?
      @state == :resolved
    end
  end

  # Produces module loaders for all modules and returns the loader for the root.
  # All other module loaders are parented by this loader. The root loader is parented by 
  # the given parent_loader.
  #
  def create_loaders(parent_loader)
    # TODO: If no root was configured - what to do? Fail? Or just run with a bunch of modules?
    # Configure a null module?
    # Create a lazy loader first, all the other modules needs to refer to something, and
    # the real module loader needs to know about the other loaders when created.
    @root_module.loader = SimpleDelegator.new(LazyLoader.new(parent_loader, @root_module, self))
    @modules.each { |md| md.loader = SimpleDelegator.new(LazyLoader.new(@root_module.loader, md, self)) }

    # Since we can be almost certain that the root loader will be used, resolve it and
    # replace with a real loader. Also, since the root module does not have a name, it can not
    # use the optimizing scheme in LazyLoader where the loader stays unresolved until a name in the
    # module's namespace is actually requested.
    @root_module.loader = @root_module.loader.create_real_loader
  end

  # Lazy loader is used via a Delegator. When invoked to do some real work, it checks
  # if the requested name is for this module or not - such a request can never come from within
  # logic in the module itself (since that would have required it to be resolved in the first place).
  #
  # TODO: must handle file based as well as gem based module when creating the real module.
  #
  class LazyLoader
    def initialize(parent, module_data, configurator)
      @module_data = module_data
      @parent = parent
      @configurator = configurator
      @miss_cache = Set.new()

      # TODO: Should check wich non namespaced paths exists within the module, there is not need to
      # check if non-namespaced entities exist if their respective root does not exist (check once instead of each
      # request. This is a join of non-namespaced types and their paths and the existing paths.
      # Later when a request is made and a check is needed, the available paths should be given to the 
      # PathBasedInstantiatorConfig (horrible name) to get the actual paths (if any).
      # Alternative approach - since modules typically have very few functions and types (typically 0 - dozen)
      # the paths can be obtained once - although this somewhat defeates the purpose of loading quickly since if there
      # are hundreds of modules, there will be 2x that number of stats to see if the respective directories exist.
      # The best combination is to do nothing on startup. When the first request is made, the check for the corresponding
      # directory is made, and the answer is remembered.

      @smart_paths = {}
    end

    def [](typed_name)
      # Since nothing has ever been loaded, this can be answered truthfully.
      nil
    end

    def load(typed_name)
      matching_name?(typed_name) ? create_real_loader.load(typed_name) : nil
    end

    def find(name, executor)
      # Calls should always go to #load first, and since that always triggers the
      # replacement and delegation to the real thing, this should never happen.
      raise "Should never have been called"
    end

    def parent
      # This can be answered truthfully without resolving the loader.
      @parent
    end

    def matching_name?(typed_name)
      segments = typed_name.name_parts
      (segments.size > 1 && @module_data.name == segments[0]) || non_namespace_name_exists?(segments[0])
    end

    def non_namespace_name_exists?(typed_name)
      type = typed_name.type
      case type
      when :function
      when :resource_type
      else
        return false
      end

      unless effective_paths = @smart_paths[type]
        # Don't know yet, does the various directories for the type exist ?
        # Get the relative dirs for the type
        paths_for_type = PathBasedInstantiatorConfig.relative_paths_for_type(type)
        root_path = @module_data.path
        # Check which directories exist and update them with the root if the they do
        effective_paths = @smart_paths[type_name.type] = paths_for_type.collect do |sp|
          FileSystem.directory?(File.join(root_path, sp.relative_path))
        end.each {|sp| sp.root_path = root_path }
      end
      # if there are no directories for this type...
      return false if effective_paths.empty?

      # have we looked before ?
      name = typed_name.name
      return false if @miss_cache.include?(name)

      # Does it have the name?
      if effective_paths.find {|sp| FileSystem.exists?(sp.absolute_path(name, 0)) }
        true
      else
        @miss_cache.add(name)
        false
      end
    end

    # Creates the real ModuleLoader, updates the Delegator handed out to other loaders earlier
    # TODO: The smart paths and miss cache are valid and can be transfered to the real loader - it will need
    # to repeat the setup and checks otherwise.
    #
    def create_real_loader
      md = @module_data
      @configurator.resolve_module md
      loaders_for_resolved = md.resolutions.collect { |m| m.loader }
      real = ModuleLoader.new(parent, md.name, md.path, loaders_for_resolved)
      md.loader.__setobj__(real)
      real
    end
  end

  # Path should refer to a directory where there are sub-directories for 'manifests', and
  # other loadable things under puppet/type, puppet/function/...
  # This does *not* add any modules found under this root.
  #
  def add_root path
    data= ModuleData.new('', :unversioned, path)
    @root_module = data 
  end

  # Path should refer to a directory of 'modules', where each directory is named after the module it contains.
  #
  def add_all_modules path
    path = path_for_uri(path, '')
    raise "Path to modules is not a directory" unless File.directory? path
    # Process content of directory in sorted order to make it deterministic
    # (Needed because types and functions are not in a namespace in Puppet; thus order matters)
    #
    Dir[file_name + '/*'].sort.each do |f|
      next unless File.directory? f
      add_module File.basename(f), f 
    end
  end

  # Path should refer to the root directory of a module. Allows a gem:, file: or nil scheme (file).
  # The path may be a URI or a String.
  #
  def add_module name, path
    # Allows specification of gem or file
    path = path_for_uri(path, '')

    # TODO:
    # Is there a modulefile.json
    # Load it, and get the metadata
    # Describe the module, its dependencies etc.
    #

    # If there is no Modulefile, or modulefile.json to load - it is still a module
    # But its version and dependencies are not known. Create a model for it
    # Mark it as "depending on everything in the configuration

    # Beware of circular dependencies; they may require special loading ?

    # Beware of same module appearing more than once (different versions ok, same version, or no
    # version is not).

    # Remember the data
    # Fake :unversioned etc.
    data = ModuleData.new(name, :unversioned, path)
    @modules << data # list in order module paths are added
    if entries = @module_name_to_data[name]
      entries << data
    else
      @module_name_to_data[name] = [data]
    end
  end

  def validate
    # Scan the remembered modules/versions and check if there are duplicate versions
    # and what not...
    # TODO: Decide when module validity is determined; tradeoff between startup performance and when
    # errors are detected

    # Validate
    # - Refers to itself, or different version of itself
    # - Metadata and path (name) are not in sync
    #
  end

  def resolve_all
    @module_name_to_data.each { |k, v| v.each { |m| resolve_module m } }
  end

  # Resolves a module by looking up all of its requirements and picking the best version
  # matching the requirements, alternatively if requirement is "everything", pick the first found
  # version of each module by name in path order.
  #
  def resolve_module md
    # list of first added (on module path) by module name
    @first_of_each ||= @modules.collect {|m| m.name }.uniq.collect {|k| @module_name_to_data[k][0] }

    #        # Alternative Collect latest, modules in order they were found on path
    #
    #        @modules.collect {|m| m.name }.uniq.collect do |k|
    #          v = theResolver.best_match(">=0", @module_name_to_data[name].collect {|x| x.version})
    #          md.resolutions << @module_name_to_data[k].find {|x| x.version == v }
    #        end

    unless md.is_resolved?
      if reqs = md.requirements
        reqs.each do |r|
          # TODO: This is pseudo code - will fail if used
          name = r.name
          version_requirements = r.version_requirements
          # Ask a (now fictitious) resolver to compute the best matching version
          v = theResolver.best_match(version_requirements, @module_name_to_data[name].collect {|x| x.version })
          if v
            md.resolutions << @module_name_to_data[name].find {|x| x.version == v }
          else
            raise "TODO: Unresolved"
          end
        end
      else
        # nil requirements means "wants to see all"
        # Possible solutions:
        # - pick the latest version of each named module if there is more than one version
        # - pick the first found module on the path (this is probably what Puppet 3x does)

        # Resolutions are all modules (except the current)        
        md.resolutions += @first_of_each.reject { |m| m == md }
      end
      md.status = :resolved
    end
  end

  def configure_loaders
  end
end
