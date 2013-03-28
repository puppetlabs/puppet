require 'delegator'

module Puppet; module Pops; module Impl; end; end; end
module Puppet::Pops::Impl::Loader

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

    def initialize
      @root_module = nil
      # maps module name to list of ModuleData (different versions of module)
      @module_name_to_data = {}
      @modules = [] # list in search path order
    end

    # =ModuleData
    # Reference to a module's data
    # TODO: should have reference to real model element containing all module data; this is faking it
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
    class LazyLoader
      def initialize parent, module_data, configurator
        @module_data = module_data
        @parent = parent
        @configurator = configurator
      end

      def [](name)
        # Since nothing has ever been loaded, this can be answered truthfully.
        nil
      end

      def load(name, executor)
        matching_name?(name) ? create_real_loader.load(name, executor) : nil
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

      def matching_name?(name)
        name = name[2..-1] if name.start_with?("::")
        segments = name.split("::")
        @module_data.name == segments[0] || (segments.size == 1 && non_namespace_name_exists?(segments[0]))
      end

      def non_namespace_name_exists? name
        # a file with given name (any extension) under /types or /functions
        Dir[*([@module_data.path].product(%w{/types /functions}, [name+'.*']).collect{|a| File.join(a)})].size != 0
      end

      # Creates the real ModuleLoader, updates the Delegator handed out to other loaders earlier
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
            # Ask a (fictitious) resolver to compute the best matching version
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
end
