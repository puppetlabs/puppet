# A validator that checks that puppet logic contains no catalog specific
# operations (classes, defines, collectors, resources, resource defaults or overrides)
# Does not prevent calling functions that have side effects on a catalog.
#
# The intended use is to first validate a parse result with the regular validator,
# and then with this second validator when a puppet program is used in a context
# where only expressions that have no side effect on a catalog are allowed.
#
class Puppet::Pops::Validation::CheckerNoCatalogExpressions

  class Factory < Puppet::Pops::Validation::Factory
    Issues = Puppet::Pops::Issues

    # Produces the checker to use
    def checker diagnostic_producer
      Puppet::Pops::Validation::CheckerNoCatalogExpressions.new(diagnostic_producer)
    end

    # Produces the label provider to use
    def label_provider
      Puppet::Pops::Model::ModelLabelProvider.new()
    end
  end

  Issues = Puppet::Pops::Issues

  attr_reader :acceptor

  # Initializes the validator with a diagnostics producer. This object must respond to
  # `:will_accept?` and `:accept`.
  #
  def initialize(diagnostics_producer)
    @@check_visitor       ||= Puppet::Pops::Visitor.new(nil, "check", 0, 0)
    @acceptor = diagnostics_producer
  end

  # Validates the entire model by visiting each model element and calling `check`.
  # The result is collected (or acted on immediately) by the configured diagnostic provider/acceptor
  # given when creating this Checker.
  #
  def validate(model)
    # tree iterate the model, and call check for each element
    check(model)
    model.eAllContents.each {|m| check(m) }
  end

  # Performs regular validity check
  def check(o)
    @@check_visitor.visit_this_0(self, o)
  end

  #---CHECKS

  def check_Object(o)
  end

  def check_Factory(o)
    check(o.current)
  end

  def check_CollectExpression(o)
    acceptor.accept(Issues::ILLEGAL_CATALOG_RELATED_EXPRESSION, o)
  end

  # for 'class', 'define'
  def check_NamedDefinition(o)
    acceptor.accept(Issues::ILLEGAL_CATALOG_RELATED_EXPRESSION, o)
  end

  def check_NodeDefinition(o)
    acceptor.accept(Issues::ILLEGAL_CATALOG_RELATED_EXPRESSION, o)
  end

  def check_QueryExpression(o)
    acceptor.accept(Issues::ILLEGAL_CATALOG_RELATED_EXPRESSION, o)
  end

  def check_ResourceExpression(o)
    acceptor.accept(Issues::ILLEGAL_CATALOG_RELATED_EXPRESSION, o)
  end

  def check_ResourceDefaultsExpression(o)
    acceptor.accept(Issues::ILLEGAL_CATALOG_RELATED_EXPRESSION, o)
  end

  def check_ResourceOverrideExpression(o)
    acceptor.accept(Issues::ILLEGAL_CATALOG_RELATED_EXPRESSION, o)
  end
end
