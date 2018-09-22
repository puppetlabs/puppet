require 'puppet/loaders'
require 'puppet/pops'

# A Catalog "compiler" that is like the regular compiler but with an API
# that is harmonized with the ScriptCompiler
#
# The Script compiler is "one shot" - it does not support rechecking if underlying source has changed or
# deal with possible errors in a cached environment.
#
class Puppet::Parser::CatalogCompiler < Puppet::Parser::Compiler

  # Evaluates the configured setup for a script + code in an environment with modules
  #
  def compile
    Puppet[:strict_variables] = true
    Puppet[:strict] = :error

    Puppet.override(rich_data: true) do
      super
    end

  rescue Puppet::ParseErrorWithIssue => detail
    detail.node = node.name
    Puppet.log_exception(detail)
    raise
  rescue => detail
    message = "#{detail} on node #{node.name}"
    Puppet.log_exception(detail, message)
    raise Puppet::Error, message, detail.backtrace
  end

  # Evaluates all added constructs, and validates the resulting catalog.
  # This can be called whenever a series of evaluation of puppet code strings
  # have reached a stable state (essentially that there are no relationships to
  # non-existing resources).
  #
  # Raises an error if validation fails.
  #
  def compile_additions
    evaluate_additions
    validate
  end

  # Evaluates added constructs that are lazily evaluated until all of them have been evaluated.
  # 
  def evaluate_additions
    evaluate_generators
    finish
  end

  # Validates the current state of the catalog.
  # Does not cause evaluation of lazy constructs.
  def validate
    validate_catalog(CatalogValidator::FINAL)
  end
end
