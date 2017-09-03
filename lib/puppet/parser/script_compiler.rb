require 'puppet/node'

require 'puppet/loaders'
require 'puppet/pops'

# A Script "compiler" that does not support catalog operations
#
# The Script compiler is "one shot" - it does not support rechecking if underlying source has changed or
# deal with possible errors in a cached environment.
#
class Puppet::Parser::ScriptCompiler
  include Puppet::Parser::AbstractCompiler

  def self.compile(node)
    new(node).compile

  rescue Puppet::ParseErrorWithIssue => detail
    detail.node = node.name
    Puppet.log_exception(detail)
    raise
  rescue => detail
    message = "#{detail} on node #{node.name}"
    Puppet.log_exception(detail, message)
    raise Puppet::Error, message, detail.backtrace
 end

  # @api private
  attr_reader :node

  # @api private
  attr_reader :facts

  # @api private
  attr_reader :topscope

  # @api private
  attr_reader :qualified_variables

  # know resources version - in regular compiler this is kept in the catalog (TODO: is, or will this be used?)
  # @api private
  attr_reader :version

  # Access to the configured loaders for 4x
  # @return [Puppet::Pops::Loader::Loaders] the configured loaders
  # @api private
  attr_reader :loaders

  def with_context_overrides(description = '', &block)
    Puppet.override( @context_overrides , description, &block)
  end

  # Evaluates the configured setup for a script + code in an environment with modules
  #
  def compile
    # TRANSLATORS, "For running script" is not user facing
    Puppet.override( @context_overrides , "For running script") do

      # Sets the node parameters for the node that is running the script as $facts variables in top scope.
      # Regular compiler sets each variable in top scope
      #
      Puppet::Util::Profiler.profile(_("Script: Set node parameters"), [:compiler, :set_node_params]) { set_node_parameters }

      # Settings are available as in the regular compiler, but there is no Class named 'settings'
      #
      Puppet::Util::Profiler.profile(_("Script: Created settings scope"), [:compiler, :create_settings_scope]) { create_settings_scope }

      #TRANSLATORS "main" is a function name and should not be translated
      Puppet::Util::Profiler.profile(_("Script: Evaluated main"), [:compiler, :evaluate_main]) { evaluate_main }
    end
  end

  # Constructs the overrides for the context
  def context_overrides()
    {
      :current_environment => environment,
      :global_scope => @topscope,             # 4x placeholder for new global scope
      :loaders  => @loaders,                  # 4x loaders
    }
  end

  # Return the node's environment.
  def environment
    node.environment
  end

  def initialize(node)
    # fix things like getting trusted information in a node parameter
    @node = sanitize_node(node)

    initvars
    # Resolutions of fully qualified variable names
    @qualified_variables = {}
  end

  # Having multiple named scopes hanging from top scope is not supported when scripting
  # in the regular compiler this is used to create one named scope per class.
  # When scripting, the "main class" is just a container of the top level code to evaluate
  # and it is not evaluated as a class added to a catalog. Since classes are not supported
  # there is no need to support the concept of "named scopes" as all variables are local
  # or in the top scope itself (notably, the $settings:: namespace is initialized
  # as just a set of variables in that namespace - there is no named scope for 'settings'
  # when scripting.
  # 
  # Keeping this method here to get specific error as being unsure if there are functions/logic
  # that will call this. The AbstractCompiler defines this method, but maybe it does not
  # have to (TODO).
  #
  def newscope(parent, options = {})
     raise _('having multiple named scopes is not supported when scripting')
  end

  private

  # Find and evaluate the main class object.
  # TODO: this is really strange, but needed for the time being since the parser creates the main class
  #
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

  # Set up all internal variables.
  def initvars
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
    Puppet.override( @context_overrides , _("For initializing script compiler")) do
      # THE MAGIC STARTS HERE ! This triggers parsing, loading etc.
      # @version = environment.known_resource_types.version
    end
  end

  # This logic is a copy of the same in Puppet::Parser::Compiler
  # We want this logic to reside elsewhere, but for now a copy is needed since the method is private
  # in the Compiler and it operates on the node that is set in the compiler.
  # The real Compiler gets the node via the indirector and there is no way to easily add code on that code
  # path, the node is therefore sanitized by the compiler. The ScriptCompiler has the same need
  # (to santize it) since it is not known where the node is coming from (although it is typically
  # the local node, and facter runs to get facts). Ideally the logic would be in 'Node'.
  #
  # This copy paste is seen as a lesser problem/risk then making a larger refactor of how
  # node is obtaqined and sanitized.
  #
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
    # do NOT set each node parameter as a top scope variable (as in regular puppet)

    # When scripting the trusted data are always local, but set them anyway
    @topscope.set_trusted(node.trusted_data)

    # Server facts are always about the local node's version etc.
    @topscope.set_server_facts(node.server_facts)

    # Set $facts for the node running the script
    facts_hash = node.facts.nil? ? {} : node.facts.values
    @topscope.set_facts(facts_hash)
  end

  def create_settings_scope
    # Do NOT create a "settings" class like the regular compiler does

    # set the fqn variables $settings::<setting>* and $settings::all_local
    #
    @topscope.merge_settings(environment.name, false)
  end
end
