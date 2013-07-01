# Configures validation suitable for the bindings model
#
class Puppet::Pops::Binder::BindingsValidatorFactory < Puppet::Pops::Validation::Factory
  # Produces the checker to use
  def checker diagnostic_producer
    Puppet::Pops::Binder::BindingsChecker.new(diagnostic_producer)
  end

  # Produces the label provider to use
  def label_provider
    Puppet::Pops::Binder::BindingsLabelProvider.new()
  end
end
