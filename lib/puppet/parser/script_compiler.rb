require 'puppet/loaders'
require 'puppet/pops'

# A Script "compiler" that does not support catalog operations
#
# The Script compiler is "one shot" - it does not support rechecking if underlying source has changed or
# deal with possible errors in a cached environment.
#
class Puppet::Parser::ScriptCompiler
  # Allows the ScriptCompiler to use the 3.x Scope class without being an actual "Compiler"
  #
  include Puppet::Parser::AbstractCompiler

  # @api private
  attr_reader :topscope

  # @api private
  attr_reader :qualified_variables

  # Access to the configured loaders for 4x
  # @return [Puppet::Pops::Loader::Loaders] the configured loaders
  # @api private
  attr_reader :loaders

  # @api private
  attr_reader :environment

  # @api private
  attr_reader :node_name

  def with_context_overrides(description = '', &block)
    Puppet.override( @context_overrides , description, &block)
  end

  # Evaluates the configured setup for a script + code in an environment with modules
  #
  def compile
    Puppet[:strict_variables] = true
    Puppet[:strict] = :error

    # TRANSLATORS, "For running script" is not user facing
    Puppet.override( @context_overrides , "For running script") do

      #TRANSLATORS "main" is a function name and should not be translated
      result = Puppet::Util::Profiler.profile(_("Script: Evaluated main"), [:script, :evaluate_main]) { evaluate_main }
      if block_given?
        yield self
      else
        result
      end
    end

  rescue Puppet::ParseErrorWithIssue => detail
    detail.node = node_name
    Puppet.log_exception(detail)
    raise
  rescue => detail
    message = "#{detail} on node #{node_name}"
    Puppet.log_exception(detail, message)
    raise Puppet::Error, message, detail.backtrace
  end

  # Constructs the overrides for the context
  def context_overrides()
    {
      :current_environment => environment,
      :global_scope => @topscope,             # 4x placeholder for new global scope
      :loaders  => @loaders,                  # 4x loaders
    }
  end

  # Create a script compiler for the given environment where errors are logged as coming
  # from the given node_name
  #
  def initialize(environment, node_name)
    @environment = environment
    @node_name = node_name

    # Create the initial scope, it is needed early
    @topscope = Puppet::Parser::Scope.new(self)

    # Initialize loaders and Pcore
    @loaders = Puppet::Pops::Loaders.new(environment)

    # Need to compute overrides here, and remember them, because we are about to
    # Expensive entries in the context are bound lazily.
    @context_overrides = context_overrides()

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

  # Find and evaluate the top level code.
  def evaluate_main
    @loaders.pre_load
    program = @loaders.load_main_manifest
    return program.nil? ? nil : Puppet::Pops::Parser::EvaluatingParser.singleton.evaluator.evaluate(program, @topscope)
  end
end
