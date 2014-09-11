class Puppet::Pops::Loaders
  class LoaderError < Puppet::Error; end

  attr_reader :static_loader
  attr_reader :puppet_system_loader
  attr_reader :public_environment_loader
  attr_reader :private_environment_loader

  def initialize(environment)
    # The static loader can only be changed after a reboot
    @@static_loader ||= Puppet::Pops::Loader::StaticLoader.new()

    # Create the set of loaders
    # 1. Puppet, loads from the "running" puppet - i.e. bundled functions, types, extension points and extensions
    #    Does not change without rebooting the service running puppet.
    #
    @@puppet_system_loader ||= create_puppet_system_loader()

    # 2. Environment loader - i.e. what is bound across the environment, may change for each setup
    #    TODO: loaders need to work when also running in an agent doing catalog application. There is no
    #    concept of environment the same way as when running as a master (except when doing apply).
    #    The creation mechanisms should probably differ between the two.
    #
    @private_environment_loader = create_environment_loader(environment)

    # 3. module loaders are set up from the create_environment_loader, they register themselves
  end

  # Clears the cached static and puppet_system loaders (to enable testing)
  #
  def self.clear
    @@static_loader = nil
    @@puppet_system_loader = nil
  end

  def static_loader
    @@static_loader
  end

  def puppet_system_loader
    @@puppet_system_loader
  end

  def public_loader_for_module(module_name)
    md = @module_resolver[module_name] || (return nil)
    # Note, this loader is not resolved until there is interest in the visibility of entities from the
    # perspective of something contained in the module. (Many request may pass through a module loader
    # without it loading anything.
    # See {#private_loader_for_module}, and not in {#configure_loaders_for_modules}
    md.public_loader
  end

  def private_loader_for_module(module_name)
    md = @module_resolver[module_name] || (return nil)
    # Since there is interest in the visibility from the perspective of entities contained in the
    # module, it must be resolved (to provide this visibility).
    # See {#configure_loaders_for_modules}
    unless md.resolved?
      @module_resolver.resolve(md)
    end
    md.private_loader
  end

  private

  def create_puppet_system_loader()
    Puppet::Pops::Loader::ModuleLoaders.system_loader_from(static_loader, self)
  end

  def create_environment_loader(environment)
    # This defines where to start parsing/evaluating - the "initial import" (to use 3x terminology)
    # Is either a reference to a single .pp file, or a directory of manifests. If the environment becomes
    # a module and can hold functions, types etc. then these are available across all other modules without
    # them declaring this dependency - it is however valuable to be able to treat it the same way
    # bindings and other such system related configuration.

    # This is further complicated by the many options available:
    # - The environment may not have a directory, the code comes from one appointed 'manifest' (site.pp)
    # - The environment may have a directory and also point to a 'manifest'
    # - The code to run may be set in settings (code)

    # Further complication is that there is nothing specifying what the visibility is into
    # available modules. (3x is everyone sees everything).
    # Puppet binder currently reads confdir/bindings - that is bad, it should be using the new environment support.

    # The environment is not a namespace, so give it a nil "module_name"
    module_name = nil
    loader_name = "environment:#{environment.name}"
    loader = Puppet::Pops::Loader::SimpleEnvironmentLoader.new(puppet_system_loader, loader_name)

    # An environment has a module path even if it has a null loader
    configure_loaders_for_modules(loader, environment)
    # modules should see this loader
    @public_environment_loader = loader

    # Code in the environment gets to see all modules (since there is no metadata for the environment)
    # but since this is not given to the module loaders, they can not load global code (since they can not
    # have prior knowledge about this
    loader = Puppet::Pops::Loader::DependencyLoader.new(loader, "environment", @module_resolver.all_module_loaders())

    # The module loader gets the private loader via a lazy operation to look up the module's private loader.
    # This does not work for an environment since it is not resolved the same way.
    # TODO: The EnvironmentLoader could be a specialized loader instead of using a ModuleLoader to do the work.
    #       This is subject to future design - an Environment may move more in the direction of a Module.
    @public_environment_loader.private_loader = loader
    loader
  end

  def configure_loaders_for_modules(parent_loader, environment)
    @module_resolver = mr = ModuleResolver.new()
    environment.modules.each do |puppet_module|
      # Create data about this module
      md = LoaderModuleData.new(puppet_module)
      mr[puppet_module.name] = md
      md.public_loader = Puppet::Pops::Loader::ModuleLoaders.module_loader_from(parent_loader, self, md.name, md.path)
    end
    # NOTE: Do not resolve all modules here - this is wasteful if only a subset of modules / functions are used
    #       The resolution is triggered by asking for a module's private loader, since this means there is interest
    #       in the visibility from that perspective.
    #       If later, it is wanted that all resolutions should be made up-front (to capture errors eagerly, this
    #       can be introduced (better for production), but may be irritating in development mode.
  end

  # =LoaderModuleData
  # Information about a Module and its loaders.
  # TODO: should have reference to real model element containing all module data; this is faking it
  # TODO: Should use Puppet::Module to get the metadata (as a hash) - a somewhat blunt instrument, but that is
  #       what is available with a reasonable API.
  #
  class LoaderModuleData

    attr_accessor :state
    attr_accessor :public_loader
    attr_accessor :private_loader
    attr_accessor :resolutions

    # The Puppet::Module this LoaderModuleData represents in the loader configuration
    attr_reader :puppet_module

    # @param puppet_module [Puppet::Module] the module instance for the module being represented
    #
    def initialize(puppet_module)
      @state = :initial
      @puppet_module = puppet_module
      @resolutions = []
      @public_loader = nil
      @private_loader = nil
    end

    def name
      @puppet_module.name
    end

    def version
      @puppet_module.version
    end

    def path
      @puppet_module.path
    end

    def resolved?
      @state == :resolved
    end

    def restrict_to_dependencies?
      @puppet_module.has_metadata?
    end

    def unmet_dependencies?
      @puppet_module.unmet_dependencies.any?
    end

    def dependency_names
      @puppet_module.dependencies_as_modules.collect(&:name)
    end
  end

  # Resolves module loaders - resolution of model dependencies is done by Puppet::Module
  #
  class ModuleResolver

    def initialize()
      @index = {}
      @all_module_loaders = nil
    end

    def [](name)
      @index[name]
    end

    def []=(name, module_data)
      @index[name] = module_data
    end

    def all_module_loaders
      @all_module_loaders ||= @index.values.map {|md| md.public_loader }
    end

    def resolve(module_data)
      if module_data.resolved?
        return
      else
        module_data.private_loader =
          if module_data.restrict_to_dependencies?
            create_loader_with_only_dependencies_visible(module_data)
          else
            create_loader_with_all_modules_visible(module_data)
          end
      end
    end

    private

    def create_loader_with_all_modules_visible(from_module_data)
      Puppet.debug("ModuleLoader: module '#{from_module_data.name}' has unknown dependencies - it will have all other modules visible")

      Puppet::Pops::Loader::DependencyLoader.new(from_module_data.public_loader, from_module_data.name, all_module_loaders())
    end

    def create_loader_with_only_dependencies_visible(from_module_data)
      if from_module_data.unmet_dependencies?
        Puppet.warning("ModuleLoader: module '#{from_module_data.name}' has unresolved dependencies"+
          " - it will only see those that are resolved."+
          " Use 'puppet module list --tree' to see information about modules")
      end
      dependency_loaders = from_module_data.dependency_names.collect { |name| @index[name].public_loader }
      Puppet::Pops::Loader::DependencyLoader.new(from_module_data.public_loader, from_module_data.name, dependency_loaders)
    end
  end
end
