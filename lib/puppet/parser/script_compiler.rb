require 'forwardable'

require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/util/errors'

require 'puppet/loaders'
require 'puppet/pops'

# Maintain a graph of scopes, along with a bunch of data
# about the individual catalog we're compiling.
class Puppet::Parser::ScriptCompiler < Puppet::Parser::Compiler
  extend Forwardable

  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::MethodHelper
  include Puppet::Pops::Evaluator::Runtime3Support

  def self.compile(node, code_id = nil)
    # In contrast to the real compiler - this compiler is a one-shot run
    # it does not check if there is a need to reparse or if there were errors
    # in the environment that lingered from earlier runs
    #
    # Just compile, the catalog is not needed
    new(node, :code_id => code_id).compile

  rescue Puppet::ParseErrorWithIssue => detail
    detail.node = node.name
    Puppet.log_exception(detail)
    raise
  rescue => detail
    message = "#{detail} on node #{node.name}"
    Puppet.log_exception(detail, message)
    raise Puppet::Error, message, detail.backtrace
 end

  attr_reader :node, :facts, :collections, :catalog, :resources, :relationships, :topscope
  attr_reader :qualified_variables

  # Access to the configured loaders for 4x
  # @return [Puppet::Pops::Loader::Loaders] the configured loaders
  # @api private
  attr_reader :loaders

  # The id of code input to the compiler.
  # @api private
  attr_accessor :code_id

  # Add a collection to the global list.
  def_delegator :@collections,   :<<, :add_collection
  def_delegator :@relationships, :<<, :add_relationship

  # Store a resource override.
  def add_override(override)
    raise _('evaluation of resource overrides is not supported when scripting')
  end

  def add_resource(scope, resource)
    type = resource.resource_type
    if type.is_a?(Puppet::Resource::Type) && type.application?
      raise _('application resources are not supported when scripting')
    end

    @resources << resource

    # Note that this will fail if the resource is not unique.
    @catalog.add_resource(resource)

    if not resource.class? and resource[:stage]
      #TRANSLATORS "stage" is a keyword in Puppet and should not be translated
      raise ArgumentError, _("Only classes can set 'stage'; normal resources like %{resource} cannot change run stage") % { resource: resource }
    end

    # Stages should not be inside of classes.  They are always a
    # top-level container, regardless of where they appear in the
    # manifest.
    return if resource.stage?

    # This adds a resource to the class it lexically appears in in the
    # manifest.
    unless resource.class?
      raise _('resources are not supported when scripting')
    end
  end

  def assert_app_in_site(scope, resource)
    raise _('asserting app in site is not supported when scripting')
  end

  # Store the fact that a class was evaluated ('' is the main class)
  def add_class(name)
    # support the main class a.k.a ''
    unless name == ''
      raise _('use of classes is not supported when scripting')
    end
  end

  # Add a catalog validator that will run at some stage to this compiler
  # @param catalog_validators [Class<CatalogValidator>] The catalog validator class to add
  def add_catalog_validator(catalog_validators)
    raise _('use of catalog validators is not supported when scripting')
  end

  def add_catalog_validators
    raise _('use of catalog validators is not supported when scripting')
  end

  # Return a list of all of the defined classes.
  def_delegator :@catalog, :classes, :classlist

  def with_context_overrides(description = '', &block)
    Puppet.override( @context_overrides , description, &block)
  end

  # Evaluates the configured setup for a script + code in an envrionment with modules
  #
  def compile
    # TRANSLATORS, "For running script" is not user facing
    Puppet.override( @context_overrides , "For running script") do
      @catalog.environment_instance = environment

      # Sets the node parameters for the node that is running the script as $facts variables in top scope.
      # Regular compiler sets each variable in top scope
      #
      Puppet::Util::Profiler.profile(_("Script: Set node parameters"), [:compiler, :set_node_params]) { set_node_parameters }

      # Settings are available as in the regular compiler, but there is not Class named 'settings'
      #
      Puppet::Util::Profiler.profile(_("Script: Created settings scope"), [:compiler, :create_settings_scope]) { create_settings_scope }

      #TRANSLATORS "main" is a function name and should not be translated
      Puppet::Util::Profiler.profile(_("Script: Evaluated main"), [:compiler, :evaluate_main]) { evaluate_main }
    end
  end

  def validate_catalog(validation_stage)
    @catalog_validators.select { |vclass| vclass.validation_stage?(validation_stage) }.each { |vclass| vclass.new(@catalog).validate }
  end

  # Constructs the overrides for the context
  def context_overrides()
    {
      :current_environment => environment,
      :global_scope => @topscope,             # 4x placeholder for new global scope
      :loaders  => @loaders,                  # 4x loaders
    }
  end

  def_delegator :@collections, :delete, :delete_collection

  # Return the node's environment.
  def environment
    node.environment
  end

  # Evaluate all of the classes specified by the node.
  # Classes with parameters are evaluated as if they were declared.
  # Classes without parameters or with an empty set of parameters are evaluated
  # as if they were included. This means classes with an empty set of
  # parameters won't conflict even if the class has already been included.
  def evaluate_node_classes
    raise _('evaluation of node classes is not supported when scripting')
  end

  # Evaluates the site - the top container for an environment catalog
  # The site contain behaves analogous to a node - for the environment catalog, node expressions are ignored
  # as the result is cross node. The site expression serves as a container for everything that is across
  # all nodes.
  #
  # @api private
  #
  def evaluate_site
    raise _('evaluation of site is not supported when scripting')
  end

  # @api private
  def on_empty_site
    # do nothing
  end

  # Prunes the catalog by dropping all resources are contained under the Site (if a site expression is used).
  # As a consequence all edges to/from dropped resources are also dropped.
  # Once the pruning is performed, this compiler returns the pruned list when calling the #resources method.
  # The pruning does not alter the order of resources in the resources list.
  #
  # @api private
  def prune_catalog
    raise _('pruning of catalog not supported when scripting')
  end

  def prune_node_catalog
    raise _('pruning of node catalog not supported when scripting')
  end

  # @api private
  def evaluate_applications
    raise _('evaluation of applications not supported when scripting')
  end

  # Evaluates each specified class in turn. If there are any classes that
  # can't be found, an error is raised. This method really just creates resource objects
  # that point back to the classes, and then the resources are themselves
  # evaluated later in the process.
  #
  def evaluate_classes(classes, scope, lazy_evaluate = true)
    raise _('evaluation of classes not supported when scripting')
  end

  def evaluate_relationships
    raise _('evaluation of relationships not supported when scripting')
  end

  # Return a resource by either its ref or its type and title.
  def_delegator :@catalog, :resource, :findresource

  def initialize(node, options = {})
    # fix things like getting trusted information in a node parameter
    @node = sanitize_node(node)
    set_options(options)
    initvars
    # Resolutions of fully qualified variable names
    @qualified_variables = {}
  end

  # Create a new scope, with either a specified parent scope or
  # using the top scope.
  def newscope(parent, options = {})
    parent ||= topscope
    scope = Puppet::Parser::Scope.new(self, options)
    scope.parent = parent
    scope
  end

  # Return any overrides for the given resource.
  def resource_overrides(resource)
    raise _('resource overrides are not supported when scripting')
  end

  private

  def ensure_classes_with_parameters(scope, hostclasses, parameters)
    raise _('ensuring classes with parameters is not supported when scripting')
  end

  def ensure_classes_without_parameters(scope, hostclasses)
    raise _('ensuring classes without parameters is not supported when scripting')
  end

  def evaluate_capability_mappings
    raise _('evaluation of capability mappings not supported when scripting')
  end

  # If ast nodes are enabled, then see if we can find and evaluate one.
  def evaluate_ast_node
    raise _('evaluation of node expression logic not supported when scripting')
  end

  # Evaluate our collections and return true if anything returned an object.
  # The 'true' is used to continue a loop, so it's important.
  def evaluate_collections
    raise _('evaluation of collections not supported when scripting')
  end

  # Make sure all of our resources have been evaluated into native resources.
  # We return true if any resources have, so that we know to continue the
  # evaluate_generators loop.
  def evaluate_definitions
    raise _('evaluation of user defined resources not supported when scripting')
  end

  # Iterate over collections and resources until we're sure that the whole
  # compile is evaluated.  This is necessary because both collections
  # and defined resources can generate new resources, which themselves could
  # be defined resources.
  def evaluate_generators
    raise _('evaluation of generators not supported when scripting')
  end

  # Find and evaluate our main object, if possible.
  def evaluate_main
    krt = environment.known_resource_types
    @main = krt.find_hostclass('')

    # short circuit the chain of evaluation done via the resource_type (the "main" class), and its code
    # via pops bridge to get to an evaluator.
    # 
    # TODO: set up with modified evaluator.
    #
    code = @main.code.program_model
    Puppet::Pops::Parser::EvaluatingParser.new().evaluate(@topscope, code)
  end

  # Make sure the entire catalog is evaluated.
  def fail_on_unevaluated
    raise _('fail_on_unevaluated is not supported when scripting')
  end

  # If there are any resource overrides remaining, then we could
  # not find the resource they were supposed to override, so we
  # want to throw an exception.
  def fail_on_unevaluated_overrides
    raise _('fail_on_unevaluated_overrides is not supported when scripting')
  end

  # Make sure there are no remaining collections that are waiting for
  # resources that have not yet been instantiated. If this occurs it
  # is an error (missing resource - it could not be realized).
  #
  def fail_on_unevaluated_resource_collections
    raise _('fail_on_unevaluated_resource_collections is not supported when scripting')
  end

  # Make sure all of our resources and such have done any last work
  # necessary.
  def finish
    # do nothing
  end

  def add_resource_metaparams
    raise _('add_resource_metaparams is not supported when scripting')
  end

  def metaparams_as_data(resource, params)
    raise _('metaparams_as_data is not supported when scripting')
  end

  # Set up all internal variables.
  def initvars
#    # The list of overrides.  This is used to cache overrides on objects
#    # that don't exist yet.  We store an array of each override.
#    @resource_overrides = Hash.new do |overs, ref|
#      overs[ref] = []
#    end

#    # The list of collections that have been created.  This is a global list,
#    # but they each refer back to the scope that created them.
#    @collections = []

#    # The list of relationships to evaluate.
#    @relationships = []

    # For maintaining the relationship between scopes and their resources.
    @catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment, @code_id)

    # MOVED HERE - SCOPE IS NEEDED (MOVE-SCOPE)
    # Create the initial scope, it is needed early
    @topscope = Puppet::Parser::Scope.new(self)

    # Initialize loaders and Pcore
    @loaders = Puppet::Pops::Loaders.new(environment)

    # Need to compute overrides here, and remember them, because we are about to
    # enter the magic zone of known_resource_types and initial import.
    # Expensive entries in the context are bound lazily.
    @context_overrides = context_overrides()

    # This construct ensures that initial import (triggered by instantiating
    # the structure 'known_resource_types') has a configured context
    # It cannot survive the initvars method, and is later reinstated
    # as part of compiling...
    #
    Puppet.override( @context_overrides , _("For initializing compiler")) do
      # THE MAGIC STARTS HERE ! This triggers parsing, loading etc.
      @catalog.version = environment.known_resource_types.version
    end

    #@catalog.add_resource(Puppet::Parser::Resource.new("stage", :main, :scope => @topscope))

    # local resource array to maintain resource ordering
    @resources = []

#    # Make sure any external node classes are in our class list
#    if @node.classes.class == Hash
#      @catalog.add_class(*@node.classes.keys)
#    else
#      @catalog.add_class(*@node.classes)
#    end
#
#    @catalog_validators = []
  end

  def sanitize_node(node)
    # Resurrect "trusted information" that comes from node/fact terminus.
    # The current way this is done in puppet db (currently the only one)
    # is to store the node parameter 'trusted' as a hash of the trusted information.
    #
    # Thus here there are two main cases:
    # 1. This terminus was used in a real agent call (only meaningful if someone curls the request as it would
    #  fail since the result is a hash of two catalogs).
    # 2  It is a command line call with a given node that use a terminus that:
    # 2.1 does not include a 'trusted' fact - use local from node trusted information
    # 2.2 has a 'trusted' fact - this in turn could be
    # 2.2.1 puppet db having stored trusted node data as a fact (not a great design)
    # 2.2.2 some other terminus having stored a fact called "trusted" (most likely that would have failed earlier, but could
    #       be spoofed).
    #
    # For the reasons above, the resurrection of trusted node data with authenticated => true is only performed
    # if user is running as root, else it is resurrected as unauthenticated.
    #
    trusted_param = node.parameters['trusted']
    if trusted_param
      # Blows up if it is a parameter as it will be set as $trusted by the compiler as if it was a variable
      node.parameters.delete('trusted')
      unless trusted_param.is_a?(Hash) && %w{authenticated certname extensions}.all? {|key| trusted_param.has_key?(key) }
        # trusted is some kind of garbage, do not resurrect
        trusted_param = nil
      end
    else
      # trusted may be Boolean false if set as a fact by someone
      trusted_param = nil
    end

    # The options for node.trusted_data in priority order are:
    # 1) node came with trusted_data so use that
    # 2) else if there is :trusted_information in the puppet context
    # 3) else if the node provided a 'trusted' parameter (parsed out above)
    # 4) last, fallback to local node trusted information
    #
    # Note that trusted_data should be a hash, but (2) and (4) are not
    # hashes, so we to_h at the end
    if !node.trusted_data
      trusted = Puppet.lookup(:trusted_information) do
        trusted_param || Puppet::Context::TrustedInformation.local(node)
      end

      # Ruby 1.9.3 can't apply to_h to a hash, so check first
      node.trusted_data = trusted.is_a?(Hash) ? trusted : trusted.to_h
    end

    node
  end

  # Set the node's parameters into the top-scope as variables.
  def set_node_parameters
    # do NOT set each node parameter as a top scope variable

    # These might be nil.
    catalog.client_version = node.parameters["clientversion"]
    catalog.server_version = node.parameters["serverversion"]

    # When scripting the trusted data are always local, but set them anyway
    @topscope.set_trusted(node.trusted_data)

    # Server facts are always about the local node's version etc.
    @topscope.set_server_facts(node.server_facts)

    # Set $facts for the node running the script
    facts_hash = node.facts.nil? ? {} : node.facts.values
    @topscope.set_facts(facts_hash)
  end

  SETTINGS = 'settings'.freeze

  def create_settings_scope
    # Do NOT create a "settings" class like the regular compiler does

    # set the fqn variables $settings::<setting>* and $settings::all_local
    #
    @topscope.merge_settings(environment.name, false)
  end

  # Return an array of all of the unevaluated resources.  These will be definitions,
  # which need to get evaluated into native resources.
  def unevaluated_resources
    # The order of these is significant for speed due to short-circuiting
    resources.reject { |resource| resource.evaluated? or resource.virtual? or resource.builtin_type? }
  end
end
