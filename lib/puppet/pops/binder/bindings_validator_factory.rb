# Configures validation suitable for the bindings model
# @api public
#
class Puppet::Pops::Binder::BindingsValidatorFactory < Puppet::Pops::Validation::Factory
  Issues = Puppet::Pops::Binder::BinderIssues

  # Produces the checker to use
  def checker diagnostic_producer
    Puppet::Pops::Binder::BindingsChecker.new(diagnostic_producer)
  end

  # Produces the label provider to use
  def label_provider
    Puppet::Pops::Binder::BindingsLabelProvider.new()
  end

  # Produces the severity producer to use
  def severity_producer
    p = super

    # Configure each issue that should **not** be an error
    #
    p[Issues::MISSING_BINDINGS] = :warning
    p[Issues::MISSING_LAYERS]   = :warning

    p
  end
end
