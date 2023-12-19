# frozen_string_literal: true
module Puppet::Pops
# A module with base functionality for validation of a model.
#
# * **Factory** - an abstract factory implementation that makes it easier to create a new validation factory.
# * **SeverityProducer** - produces a severity (:error, :warning, :ignore) for a given Issue
# * **DiagnosticProducer** - produces a Diagnostic which binds an Issue to an occurrence of that issue
# * **Acceptor** - the receiver/sink/collector of computed diagnostics
# * **DiagnosticFormatter** - produces human readable output for a Diagnostic
#
module Validation

  # This class is an abstract base implementation of a _model validation factory_ that creates a validator instance
  # and associates it with a fully configured DiagnosticProducer.
  #
  # A _validator_ is responsible for validating a model. There may be different versions of validation available
  # for one and the same model; e.g. different semantics for different puppet versions, or different types of
  # validation configuration depending on the context/type of validation that should be performed (static, vs. runtime, etc.).
  #
  # This class is abstract and must be subclassed. The subclass must implement the methods
  # {#label_provider} and {#checker}. It is also expected that the subclass will override
  # the severity_producer and configure the issues that should be reported as errors (i.e. if they should be ignored, produce
  # a warning, or a deprecation warning).
  #
  # @abstract Subclass must implement {#checker}, and {#label_provider}
  # @api public
  #
  class Factory

    # Produces a validator with the given acceptor as the recipient of produced diagnostics.
    # The acceptor is where detected issues are received (and typically collected).
    #
    # @param acceptor [Acceptor] the acceptor is the receiver of all detected issues
    # @return [#validate] a validator responding to `validate(model)`
    #
    # @api public
    #
    def validator(acceptor)
      checker(diagnostic_producer(acceptor))
    end

    # Produces the diagnostics producer to use given an acceptor of issues.
    #
    # @param acceptor [Acceptor] the acceptor is the receiver of all detected issues
    # @return [DiagnosticProducer] a detector of issues
    #
    # @api public
    #
    def diagnostic_producer(acceptor)
      DiagnosticProducer.new(acceptor, severity_producer(), label_provider())
    end

    # Produces the SeverityProducer to use
    # Subclasses should implement and add specific overrides
    #
    # @return [SeverityProducer] a severity producer producing error, warning or ignore per issue
    #
    # @api public
    #
    def severity_producer
      SeverityProducer.new
    end

    # Produces the checker to use.
    #
    # @abstract
    #
    # @api public
    #
    def checker(diagnostic_producer)
      raise NoMethodError, "checker"
    end

    # Produces the label provider to use.
    #
    # @abstract
    #
    # @api public
    #
    def label_provider
      raise NoMethodError, "label_provider"
    end
  end

  # Decides on the severity of a given issue.
  # The produced severity is one of `:error`, `:warning`, or `:ignore`.
  # By default, a severity of `:error` is produced for all issues. To configure the severity
  # of an issue call `#severity=(issue, level)`.
  #
  # @return [Symbol] a symbol representing the severity `:error`, `:warning`, or `:ignore`
  #
  # @api public
  #
  class SeverityProducer
    SEVERITIES = { ignore: true, warning: true, error: true, deprecation: true }.freeze

    # Creates a new instance where all issues are diagnosed as :error unless overridden.
    # @param [Symbol] specifies default severity if :error is not wanted as the default
    # @api public
    #
    def initialize(default_severity = :error)
      # If diagnose is not set, the default is returned by the block
      @severities = Hash.new default_severity
    end

    # Returns the severity of the given issue.
    # @return [Symbol] severity level :error, :warning, or :ignore
    # @api public
    #
    def severity(issue)
      assert_issue(issue)
      @severities[issue]
    end

    # @see {#severity}
    # @api public
    #
    def [] issue
      severity issue
    end

    # Override a default severity with the given severity level.
    #
    # @param issue [Issues::Issue] the issue for which to set severity
    # @param level [Symbol] the severity level (:error, :warning, or :ignore).
    # @api public
    #
    def []=(issue, level)
      unless issue.is_a? Issues::Issue
        raise Puppet::DevError.new(_("Attempt to set validation severity for something that is not an Issue. (Got %{issue})") % { issue: issue.class })
      end
      unless SEVERITIES[level]
        raise Puppet::DevError.new(_("Illegal severity level: %{level} for '%{issue_code}'") % { issue_code: issue.issue_code, level: level })
      end
      unless issue.demotable? || level == :error
        raise Puppet::DevError.new(_("Attempt to demote the hard issue '%{issue_code}' to %{level}") % { issue_code: issue.issue_code, level: level })
      end

      @severities[issue] = level
    end

    # Returns `true` if the issue should be reported or not.
    # @return [Boolean] this implementation returns true for errors and warnings
    #
    # @api public
    #
    def should_report? issue
      diagnose = @severities[issue]
      diagnose == :error || diagnose == :warning || diagnose == :deprecation
    end

    # Checks if the given issue is valid.
    # @api private
    #
    def assert_issue issue
      unless issue.is_a? Issues::Issue
        raise Puppet::DevError.new(_("Attempt to get validation severity for something that is not an Issue. (Got %{issue})") % { issue: issue.class })
      end
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
      # TODO: this support is questionable, it requires knowledge that :detail is special
      arguments[:detail] ||= ''

      # Accept an Error as semantic if it supports methods #file(), #line(), and #pos()
      if semantic.is_a?(StandardError)
        unless semantic.respond_to?(:file) && semantic.respond_to?(:line) && semantic.respond_to?(:pos)
          raise Puppet::DevError, _("Issue %{issue_code}: Cannot pass a %{class_name} as a semantic object when it does not support #pos(), #file() and #line()") %
              { issue_code: issue.issue_code, class_name: semantic.class }
        end
      end

      source_pos = semantic
      file = semantic.file unless semantic.nil?

      severity = @severity_producer.severity(issue)
      @acceptor.accept(Diagnostic.new(severity, issue, file, source_pos, arguments, except))
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
      # TODO: Currently unused, the intention is to provide more information (stack backtrace, etc.) when
      # debugging or similar - this to catch internal problems reported as higher level issues.
      @exception = exception
    end

    # Two diagnostics are considered equal if the have the same issue, location and severity
    # (arguments and exception are ignored)
    #
    def ==(o)
      self.class            == o.class             &&
        same_position?(o)                          &&
        issue.issue_code    == o.issue.issue_code  &&
        file                == o.file              &&
        severity            == o.severity
    end
    alias eql? ==

    # Position is equal if the diagnostic is not located or if referring to the same offset
    def same_position?(o)
      source_pos.nil? && o.source_pos.nil? || source_pos.offset == o.source_pos.offset
    end
    private :same_position?

    def hash
      @hash ||= [file, source_pos.offset, issue.issue_code, severity].hash
    end
  end

  # Formats a diagnostic for output.
  # Produces a diagnostic output typical for a compiler (suitable for interpretation by tools)
  # The format is:
  # `file:line:pos: Message`, where pos, line and file are included if available.
  #
  class DiagnosticFormatter
    def format diagnostic
      "#{format_location(diagnostic)} #{format_severity(diagnostic)}#{format_message(diagnostic)}"
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
      file = (file.is_a?(String) && file.empty?) ? nil : file
      line = pos = nil
      if diagnostic.source_pos
        line = diagnostic.source_pos.line
        pos = diagnostic.source_pos.pos
      end
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
      file = (file.is_a?(String) && file.empty?) ? nil : file
      line = pos = nil
      if diagnostic.source_pos
        line = diagnostic.source_pos.line
        pos = diagnostic.source_pos.pos
      end

      if file && line && pos
        " at #{file}:#{line}:#{pos}"
      elsif file && line
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

    # All diagnostic in the order they were issued
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

    # Returns the diagnosed errors in the order they were reported.
    def errors
      @diagnostics.select {|d| d.severity == :error }
    end

    # Returns the diagnosed warnings in the order they were reported.
    # (This includes :warning and :deprecation severity)
    def warnings
      @diagnostics.select {|d| d.severity == :warning || d.severity == :deprecation }
    end

    def errors_and_warnings
      @diagnostics.select {|d| d.severity != :ignore }
    end

    # Returns the ignored diagnostics in the order they were reported (if reported at all)
    def ignored
      @diagnostics.select {|d| d.severity == :ignore }
    end

    # Add a diagnostic, or all diagnostics from another acceptor to the set of diagnostics
    # @param diagnostic [Diagnostic, Acceptor] diagnostic(s) that should be accepted
    def accept(diagnostic)
      if diagnostic.is_a?(Acceptor)
        diagnostic.diagnostics.each {|d| _accept(d)}
      else
        _accept(diagnostic)
      end
    end

    # Prunes the contain diagnostics by removing those for which the given block returns true.
    # The internal statistics is updated as a consequence of removing.
    # @return [Array<Diagnostic, nil] the removed set of diagnostics or nil if nothing was removed
    #
    def prune(&block)
      removed = []
      @diagnostics.delete_if do |d|
        should_remove = yield(d)
        if should_remove
          removed << d
        end
        should_remove
      end
      removed.each do |d|
        case d.severity
        when :error
          @error_count -= 1
        when :warning
          @warning_count -= 1
        # there is not ignore_count
        end
      end
      removed.empty? ? nil : removed
    end

    private

    def _accept(diagnostic)
      @diagnostics << diagnostic
      case diagnostic.severity
      when :error
        @error_count += 1
      when :deprecation, :warning
        @warning_count += 1
      end
    end
  end
end
end
