module Puppet::Pops
class Loaders
  class LoaderError < Puppet::Error; end

  attr_reader :static_loader
  attr_reader :puppet_system_loader
  attr_reader :public_environment_loader
  attr_reader :private_environment_loader
  attr_reader :implementation_registry

  def initialize(environment)

    # Create the set of loaders
    # 1. Puppet, loads from the "running" puppet - i.e. bundled functions, types, extension points and extensions
    #    These cannot be cached since a  loaded instance will be bound to its closure scope which holds on to
    #    a compiler and all loaded types. Subsequent request would find remains of the environment that loaded
    #    the content. PUP-4461.
    #
    @puppet_system_loader = create_puppet_system_loader()

    # 2. Environment loader - i.e. what is bound across the environment, may change for each setup
    #    TODO: loaders need to work when also running in an agent doing catalog application. There is no
    #    concept of environment the same way as when running as a master (except when doing apply).
    #    The creation mechanisms should probably differ between the two.
    #
    @private_environment_loader = create_environment_loader(environment)

    # 3. The implementation registry maintains mappings between Puppet types and Runtime types for
    #    the current environment
    @implementation_registry = Types::ImplementationRegistry.new(@private_environment_loader)
    Pcore.init(@puppet_system_loader, @implementation_registry)

    # 4. module loaders are set up from the create_environment_loader, they register themselves
  end

  # Clears the cached static and puppet_system loaders (to enable testing)
  #
  def self.clear
    @@static_loader = nil
  end

  # Calls {#loaders} to obtain the {{Loaders}} instance and then uses it to find the appropriate loader
  # for the given `module_name`, or for the environment in case `module_name` is `nil` or empty.
  #
  # @param module_name [String,nil] the name of the module
  # @return [Loader::Loader] the found loader
  # @raise [Puppet::ParseError] if no loader can be found
  # @api private
  def self.find_loader(module_name)
    loaders.find_loader(module_name)
  end

  def self.static_loader
    # The static loader can only be changed after a reboot
    @@static_loader ||= Loader::StaticLoader.new()
  end

  def self.implementation_registry
    loaders = Puppet.lookup(:loaders) { nil }
    loaders.nil? ? nil : loaders.implementation_registry
  end

  def register_implementations(obj_classes, name_authority)
    loader = @private_environment_loader
    types = obj_classes.map do |obj_class|
      type = obj_class._ptype
      typed_name = Loader::TypedName.new(:type, type.name.downcase, name_authority)
      entry = loader.loaded_entry(typed_name)
      loader.set_entry(typed_name, type, obj_class._plocation) if entry.nil? || entry.value.nil?
      type
    end
    # Resolve lazy so that all types can cross reference each other
    parser = Types::TypeParser.singleton
    types.each { |type| type.resolve(parser, loader) }
  end

  # Register the given type with the Runtime3TypeLoader. The registration will not happen unless
  # the type system has been initialized.
  #
  # @param name [String,Symbol] the name of the entity being set
  # @param origin [URI] the origin or the source where the type is defined
  # @api private
  def self.register_runtime3_type(name, origin)
    loaders = Puppet.lookup(:loaders) { nil }
    unless loaders.nil?
      name = name.to_s
      caps_name = Types::TypeFormatter.singleton.capitalize_segments(name)
      typed_name = Loader::TypedName.new(:type, name.downcase)
      loaders.runtime3_type_loader.set_entry(typed_name, Types::PResourceType.new(caps_name), origin)
    end
    nil
  end

  # Finds the `Loaders` instance by looking up the :loaders in the global Puppet context
  #
  # @return [Loaders] the loaders instance
  # @raise [Puppet::ParseError] if loader has been bound to the global context
  # @api private
  def self.loaders
    loaders = Puppet.lookup(:loaders) { nil }
    raise Puppet::ParseError, "Internal Error: Puppet Context ':loaders' missing" if loaders.nil?
    loaders
  end

  # Finds the appropriate loader for the given `module_name`, or for the environment in case `module_name`
  # is `nil` or empty.
  #
  # @param module_name [String,nil] the name of the module
  # @return [Loader::Loader] the found loader
  # @raise [Puppet::ParseError] if no loader can be found
  # @api private
  def find_loader(module_name)
    if module_name.nil? || module_name == ''
      # TODO : Later when fdefinition can be private, a decision is needed regarding what that means.
      #        A private environment loader could be used for logic outside of modules, then only that logic
      #        would see the definition.
      #
      # Use the private loader, this definition may see the environment's dependencies (currently, all modules)
      loader = private_environment_loader()
      raise Puppet::ParseError, 'Internal Error: did not find public loader' if loader.nil?
      loader
    else
      # TODO : Later check if definition is private, and then add it to private_loader_for_module
      #
      loader = public_loader_for_module(module_name)
      raise Puppet::ParseError, "Internal Error: did not find public loader for module: '#{module_name}'" if loader.nil?
      loader
    end
  end

  def static_loader
    self.class.static_loader
  end

  def puppet_system_loader
    @puppet_system_loader
  end

  def runtime3_type_loader
    @runtime3_type_loader
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
    Loader::ModuleLoaders.system_loader_from(static_loader, self)
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
    env_conf = Puppet.lookup(:environments).get_conf(environment.name)
    env_path = env_conf.nil? || !env_conf.is_a?(Puppet::Settings::EnvironmentConf) ? nil : env_conf.path_to_env

    # Create the 3.x resource type loader
    @runtime3_type_loader = Loader::Runtime3TypeLoader.new(puppet_system_loader, environment, env_conf.nil? ? nil : env_path)

    if env_path.nil?
      # Not a real directory environment, cannot work as a module TODO: Drop when legacy env are dropped?
      loader = Loader::SimpleEnvironmentLoader.new(@runtime3_type_loader, loader_name)
    else
      # View the environment as a module to allow loading from it - this module is always called 'environment'
      loader = Loader::ModuleLoaders.module_loader_from(@runtime3_type_loader, self, 'environment', env_path)
    end

    # An environment has a module path even if it has a null loader
    configure_loaders_for_modules(loader, environment)
    # modules should see this loader
    @public_environment_loader = loader

    # Code in the environment gets to see all modules (since there is no metadata for the environment)
    # but since this is not given to the module loaders, they can not load global code (since they can not
    # have prior knowledge about this
    loader = Loader::DependencyLoader.new(loader, "environment", @module_resolver.all_module_loaders())

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
      md.public_loader = Loader::ModuleLoaders.module_loader_from(parent_loader, self, md.name, md.path)
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
      Puppet.debug{"ModuleLoader: module '#{from_module_data.name}' has unknown dependencies - it will have all other modules visible"}

      Loader::DependencyLoader.new(from_module_data.public_loader, from_module_data.name, all_module_loaders())
    end

    def create_loader_with_only_dependencies_visible(from_module_data)
      if from_module_data.unmet_dependencies?
        if Puppet[:strict] != :off
          msg = "ModuleLoader: module '#{from_module_data.name}' has unresolved dependencies" \
              " - it will only see those that are resolved." \
              " Use 'puppet module list --tree' to see information about modules"
          case Puppet[:strict]
          when :error
              raise LoaderError.new(msg)
          when :warning
            Puppet.warn_once(:unresolved_module_dependencies,
                             "unresolved_dependencies_for_module_#{from_module_data.name}",
                             msg)
          end
        end
      end
      dependency_loaders = from_module_data.dependency_names.collect { |name| @index[name].public_loader }
      Loader::DependencyLoader.new(from_module_data.public_loader, from_module_data.name, dependency_loaders)
    end
  end
end
end
