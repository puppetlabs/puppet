# A module with base functionality for validation of a model.
#
# * SeverityProducer - produces a severity (:error, :warning, :ignore) for a given Issue
# * DiagnosticProducer - produces a Diagnostic which binds an Issue to an occurrence of that issue
# * Acceptor - the receiver/sink/collector of computed diagnostics
# * DiagnosticFormatter - produces human readable output for a Diagnostic
#
module Puppet::Pops::Validation
  # Decides on the severity of a given issue.
  # The produced severity is one of `:error`, `:warning`, or `:ignore`.
  # By default, a severity of `:error` is produced for all issues. To configure the severity
  # of an issue call `#severity=(issue, level)`.
  #
  class SeverityProducer
    # Creates a new instance where all issues are diagnosed as :error unless overridden.
    #
    def initialize
      # If diagnose is not set, the default is returned by the block
      @severities = Hash.new :error
    end

    # Returns the severity of the given issue.
    # @returns [Symbol] severity level :error, :warning, or :ignore
    #
    def severity issue
      assert_issue(issue)
      @severities[issue]
    end

    def [] issue
      severity issue
    end

    # Override a default severity with the given severity level.
    #
    # @param issue [Puppet::Pops::Issues::Issue] the issue for which to set severity
    # @param level [Symbol] the severity level (:error, :warning, or :ignore).
    #
    def []= issue, level
      assert_issue(issue)
      assert_severity(level)
      raise Puppet::DevError.new("Attempt to demote the hard issue '#{issue.issue_code}' to #{level}") unless issue.demotable? || level == :error
      @severities[issue] = level
    end

    # Returns true if the issue should be reported or not.
    # @returns [Boolean] this implementation returns true for errors and warnings
    #
    def should_report? issue
      diagnose = self[issue]
      diagnose == :error || diagnose == :warning || diagnose == :deprecation
    end

    def assert_issue issue
      raise Puppet::DevError.new("Attempt to get validation severity for something that is not an Issue. (Got #{issue.class})") unless issue.is_a? Puppet::Pops::Issues::Issue
    end

    def assert_severity level
      raise Puppet::DevError.new("Illegal severity level: #{option}") unless [:ignore, :warning, :error, :deprecation].include? level
    end
  end

  # A producer of diagnostics.
  # An producer of diagnostics is given each issue occurrence as they are found by a diagnostician/validator. It then produces
  # a Diagnostic, which it passes on to a configured Acceptor.
  #
  # This class exists to aid a diagnostician/validator which will typically first check if a particular issue
  # will be accepted at all (before checking for an occurrence of the issue; i.e. to perform check avoidance for expensive checks).
  # A validator passes an instance of Issue, the semantic object (the "culprit"), a hash with arguments, and an optional
  # exception. The semantic object is used to determine the location of the occurrence of the issue (file/line), and it
  # sets keys in the given argument hash that may be used in the formatting of the issue message.
  #
  class DiagnosticProducer

    # A producer of severity for a given issue
    # @return [SeverityProducer]
    #
    attr_reader :severity_producer

    # A producer of labels for objects involved in the issue
    # @return [LabelProvider]
    #
    attr_reader :label_provider
    # Initializes this producer.
    #
    # @param acceptor [Acceptor] a sink/collector of diagnostic results
    # @param severity_producer [SeverityProducer] the severity producer to use to determine severity of a given issue
    # @param label_provider [LabelProvider] a provider of model element type to human readable label
    #
    def initialize(acceptor, severity_producer, label_provider)
      @acceptor           = acceptor
      @severity_producer  = severity_producer
      @label_provider     = label_provider
    end

    def accept(issue, semantic, arguments={}, except=nil)
      return unless will_accept? issue

      # Set label provider unless caller provided a special label provider
      arguments[:label]    ||= @label_provider
      arguments[:semantic] ||= semantic

      # A detail message is always provided, but is blank by default.
      arguments[:detail] ||= ''

      origin_adapter = Puppet::Pops::Utils.find_adapter(semantic, Puppet::Pops::Adapters::OriginAdapter)
      file = origin_adapter ? origin_adapter.origin : nil
      source_pos = Puppet::Pops::Utils.find_adapter(semantic, Puppet::Pops::Adapters::SourcePosAdapter)
      severity = @severity_producer.severity(issue)
      @acceptor.accept(Diagnostic.new(severity, issue, file, source_pos, arguments))
    end

    def will_accept? issue
      @severity_producer.should_report? issue
    end
  end

  class Diagnostic
    attr_reader :severity
    attr_reader :issue
    attr_reader :arguments
    attr_reader :exception
    attr_reader :file
    attr_reader :source_pos
    def initialize severity, issue, file, source_pos, arguments={}, exception=nil
      @severity = severity
      @issue = issue
      @file = file
      @source_pos = source_pos
      @arguments = arguments
      @exception = exception
    end
  end

  # Formats a diagnostic for output.
  # Produces a diagnostic output typical for a compiler (suitable for interpretation by tools)
  # The format is:
  # `file:line:pos: Message`, where pos, line and file are included if available.
  #
  class DiagnosticFormatter
    def format diagnostic
      "#{loc(diagnostic)} #{format_severity(diagnostic)}#{format_message(diagnostic)}"
    end

    def format_message diagnostic
      diagnostic.issue.format(diagnostic.arguments)
    end

    # This produces "Deprecation notice: " prefix if the diagnostic has :deprecation severity, otherwise "".
    # The idea is that all other diagnostics are emitted with the methods Puppet.err (or an exception), and
    # Puppet.warning.
    # @note Note that it is not a good idea to use Puppet.deprecation_warning as it is for internal deprecation.
    #
    def format_severity diagnostic
      diagnostic.severity == :deprecation ? "Deprecation notice: " : ""
    end

    def format_location diagnostic
      file = diagnostic.file
      line = diagnostic.source_pos.line
      pos = diagnostic.source_pos.pos
      if file && line && pos
        "#{file}:#{line}:#{pos}:"
      elsif file && line
        "#{file}:#{line}:"
      elsif file
        "#{file}:"
      else
        ""
      end
    end
  end

  # Produces a diagnostic output in the "puppet style", where the location is appended with an "at ..." if the
  # location is known.
  #
  class DiagnosticFormatterPuppetStyle < DiagnosticFormatter
    def format diagnostic
      if (location = format_location diagnostic) != ""
        "#{format_severity(diagnostic)}#{format_message(diagnostic)}#{location}"
      else
        format_message(diagnostic)
      end
    end

    # The somewhat (machine) unusable format in current use by puppet.
    # have to be used here for backwards compatibility.
    def format_location diagnostic
      file = diagnostic.file
      line = diagnostic.source_pos.line
      pos = diagnostic.source_pos.pos
      if file && line && pos
        " at #{file}:#{line}:#{pos}"
      elsif file and line
        " at #{file}:#{line}"
      elsif line && pos
        " at line #{line}:#{pos}"
      elsif line
        " at line #{line}"
      elsif file
        " in #{file}"
      else
        ""
      end
    end
  end

  # An acceptor of diagnostics.
  # An acceptor of diagnostics is given each issue as they are found by a diagnostician/validator. An
  # acceptor can collect all found issues, or decide to collect a few and then report, or give up as the first issue
  # if found.
  # This default implementation collects all diagnostics in the order they are produced, and can then
  # answer questions about what was diagnosed.
  #
  class Acceptor

    # All diagnstic in the order they were issued
    attr_reader :diagnostics

    # The number of :warning severity issues + number of :deprecation severity issues
    attr_reader :warning_count

    # The number of :error severity issues
    attr_reader :error_count
    # Initializes this diagnostics acceptor.
    # By default, the acceptor is configured with a default severity producer.
    # @param severity_producer [SeverityProducer] the severity producer to use to determine severity of an issue
    #
    # TODO add semantic_label_provider
    #
    def initialize()
      @diagnostics = []
      @error_count = 0
      @warning_count = 0
    end

    # Returns true when errors have been diagnosed.
    def errors?
      @error_count > 0
    end

    # Returns true when warnings have been diagnosed.
    def warnings?
      @warning_count > 0
    end

    # Returns true when errors and/or warnings have been diagnosed.
    def errors_or_warnings?
      errors? || warnings?
    end

    # Returns the diagnosed errors in the order thwy were reported.
    def errors
      @diagnostics.select {|d| d.severity == :error }
    end

    # Returns the diagnosed warnings in the order thwy were reported.
    # (This includes :warning and :deprecation severity)
    def warnings
      @diagnostics.select {|d| d.severity == :warning || d.severity == :deprecation }
    end

    def errors_and_warnings
      @diagnostics.select {|d| d.severity != :ignored}
    end

    # Returns the ignored diagnostics in the order thwy were reported (if reported at all)
    def ignored
      @diagnostics.select {|d| d.severity == :ignore }
    end

    # Add a diagnostic to the set of diagnostics
    def accept(diagnostic)
      self.send(diagnostic.severity, diagnostic)
    end

    private

    def ignore diagnostic
      @diagnostics << diagnostic
    end

    def error diagnostic
      @diagnostics << diagnostic
      @error_count += 1
    end

    def warning diagnostic
      @diagnostics << diagnostic
      @warning_count += 1
    end

    def deprecation diagnostic
      warning diagnostic
    end
  end
end
