# An Executor holds the various machine parts together:
#
# * It configures the type of top scope to use
# * How to transition from top scope to node scope
# * Which evaluator to use
# * Which DSL parser to use
# * Which DSL model validator to use
# * Configuration of loaders
#
# An Executor is also bound to a Thread local variable to enable logic to
# evaluate (nested) puppet logic without requiring that an instance of the Executor is
# passed around everywhere.
# @todo Currently the Executor saves a previously set Executor and restores it after execution.
#   this is problematic and it should probably fail as the there will be two sets of system loaders
#   etc.
#
# @api public
#
class Puppet::Pops::API::Executor
  # @return [Puppet::Pops::API::Scope] the current "top" scope (top scope, or node scope) depending on
  #  if the node scope has been entered or not.
  # @api
  attr_reader :scope

  # @return [Puppet::Pops::API::Scope] the top scope (irrespective of if node scope has been entered or not).
  # @api
  attr_reader :top_scope

  # @return [Puppet::Pops::API::Evaluator] the evaluator in use
  # @api
  attr_reader :evaluator

  # @return [Puppet::Pops::API::Loader] the static loader
  # @api private
  #
  attr_reader :static_loader

  # @return [Puppet::Pops::API::Loader] the system loader
  # @api private
  #
  attr_reader :system_loader

  # @return [Puppet::Pops::API::Loader] the plugins loader
  # @api private
  #
  attr_reader :plugins_loader

  # @return [Puppet::Pops::API::Loader] the root loader
  # @api
  #
  attr_reader :root_loader
  # Expects the given execution_configuration to:
  # @param execution_configuration [ExecutionConfiguration] configuration parameters
  #
  # @api public
  #
  def initialize execution_configuration
    configure_scopes(execution_configuration)
    configure_evaluator(execution_configuration)
    configure_loaders(execution_configuration)
  end

  # Gets the executor associated with the current Thread
  # @return [Puppet::Pops::API::Executor] the current executor
  # @api
  #
  def self.current
    Thread.current[name]
  end

  # Evaluates the given Pops model (the result of parsing)
  # @param pops_model [Object] the model to execute, evaluates many regular Objects, but is typically an
  #   instance of {Puppet::Pops::API::Model::Expression}.
  # @param options [Options] options how to perform the execution
  # @return [Object] what the evaluation of the given `pops_model` returns
  # @api public
  #
  def execute_model pops_model, options = default_options()
    # Ensure there is an origin associated with the model
    origin_adapter = OriginAdapter.adapt(parse_result.content)
    if options.override_origin
      origin_adapter.origin = origin
    else
      origin_adapter.origin ||= origin
    end

    # Ensure there is a loader associated with the model
    loader_adapter = LoaderAdapter.adapt(parse_result.content)
    loader_adapter.loader = self.send(options.loader_name) unless loader_adapter.loader

    eval_scope = case options.scope_name
    when :top_scope
      top_scope
    when :scope
      scope
    when String
      named_scope = Puppet::Pops::Impl::NamedScope.new(options.scope_name)
      named_scope.parent_scope = scope()
    end

    # Set the thread local variable to ensure "outside" access
    # Restore previous current on exit
    begin
      previous = Executor.current
      Executor.current = self

      # evaluate and return result
      evaluator.evaluate(pops_model, eval_scope)
    ensure
      Executor.current = previous
    end
  end

  # Parses and Evaluates the given (Puppet DSL) source code originating from the given origin.
  # If no origin is specified it will be the __FILE__ and __LINE__ location
  # calling this method.
  # @param code_string [String] a string with Puppet DSL source code to parse and evaluate
  # @param options [Options] options how to perform the execution
  # @return [Object] what the evaluation of the DSL returns
  #
  # @api public
  #
  def execute_code code_string, options = default_options()
    raise "TODO: Not implemented yet"
    parse_result = parse(code)
    execute_model parse_result.content
  end

  # Parses and Evaluates the given (Puppet DSL) source file.
  # @param file [String] a path to a file with Puppet DSL source code to parse and evaluate
  # @param options [Options] options how to perform the execution
  # @return [Object] what the evaluation of the DSL returns
  # @api public
  #
  def execute_file file, options = default_options()
    raise "TODO: Not implemented yet"
    parse_result = parse(code)
    execute_model parse_result.content
  end

  # Enters node scope for the host with the given node_name.
  # This will cause evaluation of the previously defined node with the given name, and
  # it's inherited node definitions as well as evaluating the "default" node (unless already
  # evaluated by inheritance).
  #
  # Once node scope has been entered it is not possible to enter it again.
  #
  # If no node is matched, the result is still that node scope is entered, and it is not
  # possible to enter it again even if there was no new information produced.
  #
  # @raise [?] when node scope has already been entered
  # @api public
  def enter_node_scope_for(node_name)
    raise "TODO EXCEPTOIN TYPE: Node scope already entered" if @selected_node
    # Enter node scope
    @scope = scope.node_scope

    # TODO: Block a new node from being selected
    # Evaluate the default node
    # Evaluated the selected node if there is a match
    raise "TODO TYPE: Not yet implemented"
  end

  # Returns true if the node scope has been entered.
  # @return [Boolean] if node scope has been entered.
  #
  # @api public
  #
  def is_node_scope_entered?
    return !!@selected_node
  end

  # Produces default options (that may be modified) and passed to the various execute methods.
  # @param origin [Origin] where the executed source originates if not encoded in the resource
  #   being executed. Defaults to the caller of this method.
  # @return [Options] a new Options object with default values, may be modified
  # @api public
  #
  def self.default_options origin = Origin.new
    opt = Options.new(origin)
  end

  # @return [Puppet::Pops::API::Loader] the loader that loads the root
  #
  # @api public
  #
  def root_loader
    @root_loader
  end

  protected

  # Configures the top scope
  # This implementation uses {Puppet::Pops::Impl::TopScope}
  # A derived implementation may override and create some other implementation.
  # @param execution_configuration [ExecutionConfiguration] configuration parameters
  # @return [void]
  #
  def configure_scopes(execution_configuration)
    @top_scope = TopScope.new()
    @scope = @top_scope
  end

  # Configures which evaluator to use.
  # This implementation uses {Puppet::Pops::Impl::EvaluatorImpl}
  # @param execution_configuration [ExecutionConfiguration] configuration parameters
  # @return [void]
  def configure_evaluator(execution_configuration)
    @evaluator = EvaluatorImpl.new()
  end

  # @return [Puppet::Pops::API::Loader] the loader that loads from the puppet runtime and plugins
  def platform_loader
    @plugin_loader
  end

  # Configures the loaders.
  # This implementation creates a static loader, a system loader, and a plugins loader
  # from information passed in the execution_configuration
  # A derived implementation may configure something else.
  # @param execution_configuration [ExecutionConfiguration] configuration parameters
  # @return [void]
  #
  def configure_loaders(execution_configuration)
    puppet_location = execution_configuration.puppet_location
    plugin_locations = execution_configuration.plugin_locations
    @static_loader = StaticLoader.new()
    @system_loader = SystemLoader.new(@static_loader, puppet_location)
    @plugins_loader = SystemLoader.new(@system_loader, plugin_locations)
    configure_module_loaders(@plugins_loader, execution_configuration)
  end

  # Configures module loaders
  # This implementation uses a {Puppet::Pops::Impl::Loader::ModuleLoaderConfigurator} to calculate
  # the configuration of modules (what is visible to each module). The result is a loader for the
  # root that sees all modules, and each module sees the modules it depends on (visibility is determined
  # by the ModuleLoaderConfigurator).
  #
  # A derived implementation may configure module loaders differently.
  #
  # @todo Allow the execution_configuration to contain exceptions/filters, skipped modules etc. since
  #   Loading is specified on entire directories of modules.
  # @param parent_loader [Puppet::Pops::API::Loader] the loader to use as the parent of each module loader
  # @param execution_configuration [ExecutionConfiguration] configuration parameters
  # @return [void]
  #
  def configure_module_loaders(parent_loader, execution_configuration)
    loader_configurator = ModuleLoaderConfigurator.new
    # The root
    loader_configurator.add_root execution_configuration.root_path

    # All other modules
    if locs = execution_configuration.module_locations
      locs.each {|p| loader_configurator.add_all_modules p}
    end
    if locs = execution_configuration.named_module_locations
      locs.each {|k,v| loader_configurator.add_module k, v }
    end

    loader_configurator.validate
    @root_loader = loader_configurator.create_loaders(parent_loader)
  end

  # Sets the current executor.
  # @private
  # @return [Puppet::Pops::API::Executor] the given `executor`
  # @api private
  #
  def self.current=(executor)
    Thread.current[name] = executor
    executor
  end

  # This class defines the API for providing configuration information to an Executor.
  #
  # The configuration information mostly consists of paths to various locations, and/or URIs
  # to locations and gems (where is puppet, where is the root, where are modules to be found, etc.).
  #
  # @api public
  #
  class ExecutionConfiguration
    # @return [String] the file system location of the puppet root (i.e. where 'lib/puppet' is located).
    #
    # @api public
    #
    attr_accessor :puppet_location

    # @return [Array<String>] an array of locations where each entry is either a path
    #   or a URI with one of the schemes `file:`, _(none)_, or `gem:`. These locations should refer to
    #   a place where 'lib/puppet'
    #   can be found, or in the case of `gem:`, optionally a location containing what 'lib/puppet' contains relative
    #   to the gem's root.
    #
    # @api public
    #
    attr_accessor :plugin_location

    # @return [String] the root directory location. This path may not be null, and the directory must exist.
    #
    # @api public
    #
    attr_accessor :root_path

    # @return [Array<String>, nil] an array of file paths/URIs where
    #   uri's are `file:`, _(none)_, or `gem:` schemed. It is also expected that any references to variables
    #   etc. have been resolved in the paths. It is further expected that each path refers to a directory
    #   containing sub directories where each such sub-directory represents a module by name.
    #   A nil, or empty response is accepted. If an entry is specified, it must refer to something that exists.
    #
    # @api public
    #
    attr_accessor :module_locations

    # @return [Hash<{String => String}], nil] a hash mapping module-name to root path of module. A nil or
    #   empty response is accepted. If an entry is specified, it must refer to something that exists.
    #
    # @api public
    #
    attr_accessor :named_module_locations
  end

  # Executor evaluation options.
  #
  # This class defines the options that can be passed to an Executor.
  # @see Puppet::Pops::API::Executor.default_options Executor#default_options
  #
  # @api public
  #
  class Options
    # An {Puppet::Pops::API::Origin} describing where the evaluated code originated. Will be set to
    # the callers `__FILE__, __LINE__` by default if nothing is stated. Will take effect
    # in the executor if the evaluated logic does not have an origin already. Also see {#override_origin}
    # @return [Puppet::Pops::API::Origin, #uri] origin of evaluated code
    #
    # @api public
    #
    attr_accessor :origin

    # When true, the given `origin` will be used to override any origin in the evaluated code.
    # This is useful in special circumstances (a file is parsed and then used in multiple tests, perhaps
    # after mutation of the model). The default is `false`.
    # @return [Boolean] if the origin in options should override origin in code
    #
    # @api public
    #
    attr_accessor :override_origin

    # The name of the scope to perform the evaluation in. By default `:scope`, which is either `:top_scope` or
    # `:node_scope` depending on if node scope has been entered or not.
    #
    # @note Advanced
    #
    #   Any other name should be a string, and be a fully qualified name without a leading "::".
    #   The option to specify a name is primarily intended for testing, and tools that need to simulate evaluation
    #   of logic inside the scope of a namespace.
    #
    # @api public
    # @return [Symbol] symbolic scope name
    # @return [String] the name of a named scope (advanced)
    #
    attr_accessor :scope_name

    # The name of the loader to use when performing evaluation. The loader is responsible for
    # loading types, functions, definitions and classes. A loader provides a perspective of visible
    # things to load. The available loaders are determined by the implementation of Executor
    # that is configured. Only the name `:root_loader` is defined by the API and must be supported
    # by all implementations.
    # The default is `:root_loader` (i.e. in the perspective of the root and all available modules).
    #
    # @todo provide a way to specify a specific module's loader. This requires that the configurator
    #   produces a map from name/version combination to loader. This is somewhat complex to use since name
    #   is not enough, and a user requesting a particular module scope must first determine which version (or
    #   'latest') that is wanted, and then set the option. Supporting this may be valuable when testing and
    #   for other tools. A way to do this is perhaps to give a path to a file in a module to serve as
    #   point of reference for a "perspective".
    # @todo additional load names should perhaps be available (evaluate in context of plugins, only puppet
    #   etc.)
    #
    # @api public
    # @return [Symbol] the name of the loader
    #
    attr_accessor :loader_name
    # Creates a new Option with scope set to `:scope` and _loader_name_ set to `:root_loader`,
    # _override_origin_ set to `false` and _origin_ to the optionally given _origin_.
    #
    # @param origin [Puppet::Pops::API::Origin] an optional origin, if not given, a default origin
    #   referencing the file and line of the caller of this method.
    # @api public
    #
    def initialize origin = Origin.new
      @origin = origin
      @override_origin = false
      @scope_name = :scope
      @loader_name = :root_loader
    end
  end
end
