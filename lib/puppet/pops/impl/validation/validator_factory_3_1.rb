require 'puppet/pops/api'

module Puppet; end

module Puppet::Pops; end

module Puppet::Pops::Impl; end

module Puppet::Pops::Impl::Validation
  # Configures validation suitable for 3.1 + iteration
  #
  class ValidatorFactory_3_1
    Issues = Puppet::Pops::API::Issues

    # Produces a validator with the given acceptor as the recipient of produced diagnostics.
    #
    def validator acceptor
      checker(diagnostic_producer(acceptor))
    end

    # Produces the diagnostics producer to use given an acceptor as the recipient of produced diagnostics
    #
    def diagnostic_producer acceptor
      Puppet::Pops::API::Validation::DiagnosticProducer.new(acceptor, severity_producer(), label_provider())
    end

    # Produces the checker to use
    def checker diagnostic_producer
      Puppet::Pops::Impl::Validation::Checker3_1.new(diagnostic_producer)
    end

    # Produces the label provider to use
    def label_provider
      Puppet::Pops::Impl::Model::ModelLabelProvider.new()
    end

    # Produces the severity producer to use
    def severity_producer
      p = Puppet::Pops::API::Validation::SeverityProducer.new

      # Configure each issue that should **not** be an error
      #
      p[Issues::RT_NO_STORECONFIGS_EXPORT]    = :warning
      p[Issues::RT_NO_STORECONFIGS]           = :warning
      p[Issues::NAME_WITH_HYPHEN]             = :deprecation
      p[Issues::DEPRECATED_NAME_AS_TYPE]      = :deprecation

      p
    end
  end
end
