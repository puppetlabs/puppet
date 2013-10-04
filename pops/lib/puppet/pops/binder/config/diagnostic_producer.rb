module Puppet::Pops::Binder::Config
  # Generates validation diagnostics
  class Puppet::Pops::Binder::Config::DiagnosticProducer
    def initialize(acceptor)
      @acceptor = acceptor
      @severity_producer = Puppet::Pops::Validation::SeverityProducer.new
    end

    def accept(issue, semantic, arguments={})
      arguments[:semantic] ||= semantic
      severity = severity_producer.severity(issue)
      @acceptor.accept(Puppet::Pops::Validation::Diagnostic.new(severity, issue, nil, nil, arguments))
    end

    def errors?()
      @acceptor.errors?
    end

    def severity_producer
      p = @severity_producer
      # All are errors, if there is need to mark some as warnings...
      # p[Issues::XXX] = :warning

      # ignored because there is a default
      p[Puppet::Pops::Binder::Config::Issues::CONFIG_LAYERS_MISSING] = :ignore

      # ignored because there is a default
      p[Puppet::Pops::Binder::Config::Issues::CONFIG_CATEGORIES_MISSING] = :ignore
      p
    end
  end
end
