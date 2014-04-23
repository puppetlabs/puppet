class Puppet::Pops::Loaders
  class LoaderError < Puppet::Error; end

  attr_reader :static_loader
  attr_reader :puppet_system_loader
  attr_reader :public_environment_loader
  attr_reader :private_environment_loader

  def initialize()
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
    @private_environment_loader = create_environment_loader()

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

  def self.create_loaders()
    self.new()
  end

  def public_loader_for_module(module_name)
    md = @module_resolver[module_name] || (return nil)
    # Note, this loader is not resolved until it is asked to load something it may contain
    md.public_loader
  end

  def private_loader_for_module(module_name)
    md = @module_resolver[module_name] || (return nil)
    unless md.resolved?
      @module_resolver.resolve(md)
    end
    md.private_loader
  end

  private

  def create_puppet_system_loader()
    module_name = nil
    loader_name = 'puppet_system'

    # Puppet system may be installed in a fixed location via RPM, installed as a Gem, via source etc.
    # The only way to find this across the different ways puppet can be installed is
    # to search up the path from this source file's __FILE__ location until it finds the parent of
    # lib/puppet... e.g.. dirname(__FILE__)/../../..  (i.e. <somewhere>/lib/puppet/pops/loaders.rb).
    #
    puppet_lib = File.join(File.dirname(__FILE__), '../../..')
    Puppet::Pops::Loader::ModuleLoaders::FileBased.new(static_loader, module_name, puppet_lib, loader_name)
  end

  def create_environment_loader()
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

    current_environment = Puppet.lookup(:current_environment)
    # The environment is not a namespace, so give it a nil "module_name"
    module_name = nil
    loader_name = "environment:#{current_environment.name}"
    env_dir = Puppet[:environmentdir]
    if env_dir.nil?
      # Use an environment loader that can be populated externally
      loader = Puppet::Pops::Loader::SimpleEnvironmentLoader.new(puppet_system_loader, loader_name)
    else
      envdir_path = File.join(env_dir, current_environment.name.to_s)
      # TODO: Representing Environment as a Module - needs something different (not all types are supported),
      # and it must be able to import .pp code from 3x manifest setting, or from code setting as well as from
      # a manifests directory under the environment's root. The below is cheating...
      #
      loader = Puppet::Pops::Loader::ModuleLoaders::FileBased(puppet_system_loader, module_name, envdir_path, loader_name)
    end
    # An environment has a module path even if it has a null loader
    configure_loaders_for_modules(loader, current_environment)
    # modules should see this loader
    @public_environment_loader = loader

    # Code in the environment gets to see all modules (since there is no metadata for the environment)
    # but since this is not given to the module loaders, they can not load global code (since they can not
    # have prior knowledge about this
    loader = Puppet::Pops::Loader::DependencyLoader.new(loader, "environment", @module_resolver.all_module_loaders())

    loader
  end

  def configure_loaders_for_modules(parent_loader, current_environment)
    @module_resolver = mr = ModuleResolver.new()
    current_environment.modules.each do |puppet_module|
      # Create data about this module
      md = LoaderModuleData.new(puppet_module)
      mr[puppet_module.name] = md
      md.public_loader = Puppet::Pops::Loader::ModuleLoaders::FileBased.new(parent_loader, md.name, md.path, md.name)
    end
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

    def requirements
      nil # FAKE: this says "wants to see everything"
    end

    def resolved?
      @state == :resolved
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
      return if module_data.resolved?
      pm = module_data.puppet_module
      # Resolution rules
      # If dependencies.nil? means "see all other modules" (This to make older modules work, and modules w/o metadata)
      # TODO: Control via flag/feature ?
      module_data.private_loader =
      if pm.dependencies.nil?
        # see everything
        if Puppet::Util::Log.level == :debug
          Puppet.debug("ModuleLoader: module '#{module_data.name}' has unknown dependencies - it will have all other modules visible")
        end

        Puppet::Pops::Loader::DependencyLoader.new(module_data.loader, module_data.name, all_module_loaders())
      else
        # If module has resolutions they must resolve - it will not see into other modules otherwise
        # TODO: possible give errors if there are unresolved references
        #       i.e. !pm.unmet_dependencies.empty? (if module lacks metadata it is considered to have met all).
        #       The face "module" can display error information.
        #       Here, we are just giving up without explaining - the user can check with the module face (or console)
        #
        unless pm.unmet_dependencies.empty?
          # TODO: Exception or just warning?
          Puppet.warning("ModuleLoader: module '#{module_data.name}' has unresolved dependencies"+
            " - it will only see those that are resolved."+
            " Use 'puppet module list --tree' to see information about modules")
            #  raise Puppet::Pops::Loader::Loader::Error, "Loader Error: Module '#{module_data.name}' has unresolved dependencies - use 'puppet module list --tree' to see information"
        end
        dependency_loaders = pm.dependencies_as_modules.map { |dep| @index[dep.name].loader }
        Puppet::Pops::Loader::DependencyLoader.new(module_data.loader, module_data.name, dependency_loaders)
      end

    end
  end
end