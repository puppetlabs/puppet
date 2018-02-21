module Puppet::Pops
# This is the container for all Loader instances. Each Loader instance has a `loader_name` by which it can be uniquely
# identified within this container.
# A Loader can be private or public. In general, code will have access to the private loader associated with the
# location of the code. It will be parented by a loader that in turn have access to other public loaders that
# can load only such entries that have been publicly available. The split between public and private is not
# yet enforced in Puppet.
#
# The name of a private loader should always end with ' private'
#
class Loaders
  class LoaderError < Puppet::Error; end

  attr_reader :static_loader
  attr_reader :puppet_system_loader
  attr_reader :public_environment_loader
  attr_reader :private_environment_loader
  attr_reader :environment

  def self.new(environment, for_agent = false)
    obj = environment.loaders
    if obj.nil?
      obj = self.allocate
      obj.send(:initialize, environment, for_agent)
    end
    obj
  end

  def initialize(environment, for_agent)
    # Protect against environment havoc
    raise ArgumentError.new(_("Attempt to redefine already initialized loaders for environment")) unless environment.loaders.nil?
    environment.loaders = self
    @environment = environment
    @loaders_by_name = {}

    add_loader_by_name(self.class.static_loader)

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
    @private_environment_loader = if for_agent
      add_loader_by_name(Loader::SimpleEnvironmentLoader.new(@puppet_system_loader, 'agent environment'))
    else
      create_environment_loader(environment)
    end

    Pcore.init_env(@private_environment_loader)

    # 3. module loaders are set up from the create_environment_loader, they register themselves
  end

  # Called after loader has been added to Puppet Context as :loaders so that dynamic types can
  # be pre-loaded with a fully configured loader system
  def pre_load
    @puppet_system_loader.load(:type, 'error')

    # Will move to Bolt
    @puppet_system_loader.load(:type, 'executionresult')
  end

  # Clears the cached static and puppet_system loaders (to enable testing)
  #
  def self.clear
    @@static_loader = nil
    Model.class_variable_set(:@@pcore_ast_initialized, false)
    Model.register_pcore_types
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

  def self.static_implementation_registry
    if !class_variable_defined?(:@@static_implementation_registry) || @@static_implementation_registry.nil?
      ir = Types::ImplementationRegistry.new
      Types::TypeParser.type_map.values.each { |t| ir.register_implementation(t.simple_name, t.class.name) }
      @@static_implementation_registry = ir
    end
    @@static_implementation_registry
  end

  def self.static_loader
    # The static loader can only be changed after a reboot
    if !class_variable_defined?(:@@static_loader) || @@static_loader.nil?
      @@static_loader = Loader::StaticLoader.new()
      @@static_loader.register_aliases
      Pcore.init(@@static_loader, static_implementation_registry)
    end
    @@static_loader
  end

  def self.implementation_registry
    loaders = Puppet.lookup(:loaders) { nil }
    loaders.nil? ? nil : loaders.implementation_registry
  end

  def register_implementations(obj_classes, name_authority)
    self.class.register_implementations_with_loader(obj_classes, name_authority, @private_environment_loader)
  end

  # Register implementations using the global static loader
  def self.register_static_implementations(obj_classes)
    register_implementations_with_loader(obj_classes, Pcore::RUNTIME_NAME_AUTHORITY, static_loader)
  end

  def self.register_implementations_with_loader(obj_classes, name_authority, loader)
    types = obj_classes.map do |obj_class|
      type = obj_class._pcore_type
      typed_name = Loader::TypedName.new(:type, type.name, name_authority)
      entry = loader.loaded_entry(typed_name)
      loader.set_entry(typed_name, type) if entry.nil? || entry.value.nil?
      type
    end
    # Resolve lazy so that all types can cross reference each other
    types.each { |type| type.resolve(loader) }
  end

  # Register the given type with the Runtime3TypeLoader. The registration will not happen unless
  # the type system has been initialized.
  #
  # @param name [String,Symbol] the name of the entity being set
  # @param origin [URI] the origin or the source where the type is defined
  # @api private
  def self.register_runtime3_type(name, origin)
    loaders = Puppet.lookup(:loaders) { nil }
    return nil if loaders.nil?

    rt3_loader = loaders.runtime3_type_loader
    return nil if rt3_loader.nil?

    name = name.to_s
    caps_name = Types::TypeFormatter.singleton.capitalize_segments(name)
    typed_name = Loader::TypedName.new(:type, name)
    rt3_loader.set_entry(typed_name, Types::PResourceType.new(caps_name), origin)
    nil
  end

  # Finds a loader to use when deserializing a catalog and then subsequenlty use user
  # defined types found in that catalog.
  #
  def self.catalog_loader
    loaders = Puppet.lookup(:loaders) { nil }
    if loaders.nil?
      loaders = Loaders.new(Puppet.lookup(:current_environment), true)
      Puppet.push_context(:loaders => loaders)
    end
    loaders.find_loader(nil)
  end

  # Finds the `Loaders` instance by looking up the :loaders in the global Puppet context
  #
  # @return [Loaders] the loaders instance
  # @raise [Puppet::ParseError] if loader has been bound to the global context
  # @api private
  def self.loaders
    loaders = Puppet.lookup(:loaders) { nil }
    raise Puppet::ParseError, _("Internal Error: Puppet Context ':loaders' missing") if loaders.nil?
    loaders
  end

  # Lookup a loader by its unique name.
  #
  # @param [String] loader_name the name of the loader to lookup
  # @return [Loader] the found loader
  # @raise [Puppet::ParserError] if no loader is found
  def [](loader_name)
    loader = @loaders_by_name[loader_name]
    if loader.nil?
      # Unable to find the module private loader. Try resolving the module
      loader = private_loader_for_module(loader_name[0..-9]) if loader_name.end_with?(' private')
      raise Puppet::ParseError, _("Unable to find loader named '%{loader_name}'") % { loader_name: loader_name } if loader.nil?
    end
    loader
  end

  # Finds the appropriate loader for the given `module_name`, or for the environment in case `module_name`
  # is `nil` or empty.
  #
  # @param module_name [String,nil] the name of the module
  # @return [Loader::Loader] the found loader
  # @raise [Puppet::ParseError] if no loader can be found
  # @api private
  def find_loader(module_name)
    if module_name.nil? || EMPTY_STRING == module_name
      # Use the public environment loader
      public_environment_loader
    else
      # TODO : Later check if definition is private, and then add it to private_loader_for_module
      #
      loader = public_loader_for_module(module_name)
      if loader.nil?
        raise Puppet::ParseError, _("Internal Error: did not find public loader for module: '%{module_name}'") % { module_name: module_name }
      end
      loader
    end
  end

  def implementation_registry
    # Environment specific implementation registry
    @implementation_registry ||= Types::ImplementationRegistry.new(self.class.static_implementation_registry)
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

  def add_loader_by_name(loader)
    name = loader.loader_name
    if @loaders_by_name.include?(name)
      raise Puppet::ParseError, _("Internal Error: Attempt to redefine loader named '%{name}'") % { name: name }
    end
    @loaders_by_name[name] = loader
  end

  # Load the main manifest for the given environment
  #
  # There are two sources that can be used for the initial parse:
  #
  #   1. The value of `Puppet[:code]`: Puppet can take a string from
  #     its settings and parse that as a manifest. This is used by various
  #     Puppet applications to read in a manifest and pass it to the
  #     environment as a side effect. This is attempted first.
  #   2. The contents of the environment's +manifest+ attribute: Puppet will
  #     try to load the environment manifest. The manifest must be a file.
  #
  # @return [Model::Program] The manifest parsed into a model object
  def load_main_manifest
    parser = Parser::EvaluatingParser.singleton
    parsed_code = Puppet[:code]
    program = if parsed_code != ""
      parser.parse_string(parsed_code, 'unknown-source-location')
    else
      file = @environment.manifest

      # if the manifest file is a reference to a directory, parse and combine
      # all .pp files in that directory
      if file == Puppet::Node::Environment::NO_MANIFEST
        nil
      elsif File.directory?(file)
        raise Puppet::Error, "manifest of environment '#{@environment.name}' appoints directory '#{file}'. It must be a file"
      elsif File.exists?(file)
        parser.parse_file(file)
      else
        raise Puppet::Error, "manifest of environment '#{@environment.name}' appoints '#{file}'. It does not exist"
      end
    end
    instantiate_definitions(program, public_environment_loader) unless program.nil?
    program
  rescue Puppet::ParseErrorWithIssue => detail
    detail.environment = @environment.name
    raise
  rescue => detail
    msg = _('Could not parse for environment %{env}: %{detail}') % { env: @environment, detail: detail }
    error = Puppet::Error.new(msg)
    error.set_backtrace(detail.backtrace)
    raise error
  end

  # Add 4.x definitions found in the given program to the given loader.
  def instantiate_definitions(program, loader)
    program.definitions.each { |d| instantiate_definition(d, loader) }
    nil
  end

  # Add given 4.x definition to the given loader.
  def instantiate_definition(definition, loader)
    case definition
    when Model::PlanDefinition
      instantiate_PlanDefinition(definition, loader)
    when Model::FunctionDefinition
      instantiate_FunctionDefinition(definition, loader)
    when Model::TypeAlias
      instantiate_TypeAlias(definition, loader)
    when Model::TypeMapping
      instantiate_TypeMapping(definition, loader)
    else
      raise Puppet::ParseError, "Internal Error: Unknown type of definition - got '#{definition.class}'"
    end
  end

  private

  def instantiate_PlanDefinition(plan_definition, loader)
    typed_name, f = Loader::PuppetPlanInstantiator.create_from_model(plan_definition, loader)
    loader.set_entry(typed_name, f, plan_definition.locator.to_uri(plan_definition))
    nil
  end

  def instantiate_FunctionDefinition(function_definition, loader)
    # Instantiate Function, and store it in the loader
    typed_name, f = Loader::PuppetFunctionInstantiator.create_from_model(function_definition, loader)
    loader.set_entry(typed_name, f, function_definition.locator.to_uri(function_definition))
    nil
  end

  def instantiate_TypeAlias(type_alias, loader)
    # Bind the type alias to the loader using the alias
    Puppet::Pops::Loader::TypeDefinitionInstantiator.create_from_model(type_alias, loader)
    nil
  end

  def instantiate_TypeMapping(type_mapping, loader)
    tf = Types::TypeParser.singleton
    lhs = tf.interpret(type_mapping.type_expr, loader)
    rhs = tf.interpret_any(type_mapping.mapping_expr, loader)
    implementation_registry.register_type_mapping(lhs, rhs)
    nil
  end

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

    # env_conf is setup from the environment_dir value passed into Puppet::Environments::Directories.new
    env_conf = Puppet.lookup(:environments).get_conf(environment.name)
    env_path = env_conf.nil? || !env_conf.is_a?(Puppet::Settings::EnvironmentConf) ? nil : env_conf.path_to_env

    if Puppet[:tasks]
      loader = Loader::ModuleLoaders.environment_loader_from(puppet_system_loader, self, env_path)
    else
      # Create the 3.x resource type loader
      static_loader.runtime_3_init
      @runtime3_type_loader = add_loader_by_name(Loader::Runtime3TypeLoader.new(puppet_system_loader, self, environment, env_conf.nil? ? nil : env_path))

      if env_path.nil?
        # Not a real directory environment, cannot work as a module TODO: Drop when legacy env are dropped?
        loader = add_loader_by_name(Loader::SimpleEnvironmentLoader.new(@runtime3_type_loader, Loader::ENVIRONMENT))
      else
        # View the environment as a module to allow loading from it - this module is always called 'environment'
        loader = Loader::ModuleLoaders.environment_loader_from(@runtime3_type_loader, self, env_path)
      end
    end

    # An environment has a module path even if it has a null loader
    configure_loaders_for_modules(loader, environment)
    # modules should see this loader
    @public_environment_loader = loader

    # Code in the environment gets to see all modules (since there is no metadata for the environment)
    # but since this is not given to the module loaders, they can not load global code (since they can not
    # have prior knowledge about this
    loader = add_loader_by_name(Loader::DependencyLoader.new(loader, Loader::ENVIRONMENT_PRIVATE, @module_resolver.all_module_loaders()))

    # The module loader gets the private loader via a lazy operation to look up the module's private loader.
    # This does not work for an environment since it is not resolved the same way.
    # TODO: The EnvironmentLoader could be a specialized loader instead of using a ModuleLoader to do the work.
    #       This is subject to future design - an Environment may move more in the direction of a Module.
    @public_environment_loader.private_loader = loader
    loader
  end

  def configure_loaders_for_modules(parent_loader, environment)
    @module_resolver = mr = ModuleResolver.new(self)
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

    attr_accessor :public_loader
    attr_accessor :private_loader
    attr_accessor :resolutions

    # The Puppet::Module this LoaderModuleData represents in the loader configuration
    attr_reader :puppet_module

    # @param puppet_module [Puppet::Module] the module instance for the module being represented
    #
    def initialize(puppet_module)
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
      !@private_loader.nil?
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

    def initialize(loaders)
      @loaders = loaders
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
        nil
      else
        module_data.private_loader =
          if module_data.restrict_to_dependencies? && !Puppet[:tasks]
            create_loader_with_only_dependencies_visible(module_data)
          else
            create_loader_with_all_modules_visible(module_data)
          end
      end
    end

    private

    def create_loader_with_all_modules_visible(from_module_data)
      Puppet.debug{"ModuleLoader: module '#{from_module_data.name}' has unknown dependencies - it will have all other modules visible"}

      @loaders.add_loader_by_name(Loader::DependencyLoader.new(from_module_data.public_loader, "#{from_module_data.name} private", all_module_loaders()))
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
      @loaders.add_loader_by_name(Loader::DependencyLoader.new(from_module_data.public_loader, "#{from_module_data.name} private", dependency_loaders))
    end
  end
end
end
