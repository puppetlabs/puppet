module Puppet::Pops
module Binder
module Config
  # Generates validation diagnostics
  class DiagnosticProducer
    def initialize(acceptor)
      @acceptor = acceptor
      @severity_producer = Validation::SeverityProducer.new
    end

    def accept(issue, semantic, arguments={})
      arguments[:semantic] ||= semantic
      severity = severity_producer.severity(issue)
      @acceptor.accept(Validation::Diagnostic.new(severity, issue, nil, nil, arguments))
    end

    def errors?()
      @acceptor.errors?
    end

    def severity_producer
      p = @severity_producer
      # All are errors, if there is need to mark some as warnings...
      # p[Issues::XXX] = :warning

      # ignored because there is a default
      p[Issues::CONFIG_LAYERS_MISSING] = :ignore

      # ignored because there is a default
      p[Issues::CONFIG_CATEGORIES_MISSING] = :ignore
      p
    end
  end
end
end
end
