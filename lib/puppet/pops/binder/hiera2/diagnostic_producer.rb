module Puppet::Pops::Binder::Hiera2
  # Generates validation diagnostics
  class Puppet::Pops::Binder::Hiera2::DiagnosticProducer
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
      p[Issues::UNRESOLVED_STRING_VARIABLE] = :warning
      p
    end
  end
end
