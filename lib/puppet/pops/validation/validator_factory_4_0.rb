module Puppet::Pops
module Validation
# Configures validation suitable for 4.0
#
class ValidatorFactory_4_0 < Factory
  Issues = Issues

  # Produces the checker to use
  def checker diagnostic_producer
    if Puppet[:tasks]
      require_relative 'tasks_checker'
      TasksChecker.new(diagnostic_producer)
    else
      Checker4_0.new(diagnostic_producer)
    end
  end

  # Produces the label provider to use
  def label_provider
    Model::ModelLabelProvider.new()
  end

  # Produces the severity producer to use
  def severity_producer
    p = super

    # Configure each issue that should **not** be an error
    #
    # Validate as per the current runtime configuration
    p[Issues::RT_NO_STORECONFIGS_EXPORT]    = Puppet[:storeconfigs] ? :ignore : :warning
    p[Issues::RT_NO_STORECONFIGS]           = Puppet[:storeconfigs] ? :ignore : :warning

    p[Issues::FUTURE_RESERVED_WORD]          = :deprecation

    p[Issues::DUPLICATE_KEY]                 = Puppet[:strict] == :off ? :ignore : Puppet[:strict]
    p[Issues::NAME_WITH_HYPHEN]              = :error
    p[Issues::EMPTY_RESOURCE_SPECIALIZATION] = :ignore
    p[Issues::CLASS_NOT_VIRTUALIZABLE]      = Puppet[:strict] == :off ? :warning : Puppet[:strict]
    p
  end
end
end
end
