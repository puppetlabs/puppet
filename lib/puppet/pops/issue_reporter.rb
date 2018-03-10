module Puppet::Pops
class IssueReporter

  # @param acceptor [Validation::Acceptor] the acceptor containing reported issues
  # @option options [String] :message (nil) A message text to use as prefix in
  #   a single Error message
  # @option options [Boolean] :emit_warnings (false) whether warnings should be emitted
  # @option options [Boolean] :emit_errors (true) whether errors should be
  #   emitted or only the given message
  # @option options [Exception] :exception_class (Puppet::ParseError) The exception to raise
  #
  def self.assert_and_report(acceptor, options)
    return unless acceptor

    max_errors       = options[:max_errors]   || Puppet[:max_errors]
    max_warnings     = options[:max_warnings] || Puppet[:max_warnings]
    max_deprecations = options[:max_deprecations] || (Puppet[:disable_warnings].include?('deprecations') ? 0 : Puppet[:max_deprecations])

    emit_warnings    = options[:emit_warnings] || false
    emit_errors      = options[:emit_errors].nil? ? true : !!options[:emit_errors]
    emit_message     = options[:message]
    emit_exception   = options[:exception_class] || Puppet::ParseErrorWithIssue

    # If there are warnings output them
    warnings = acceptor.warnings
    if emit_warnings && warnings.size > 0
      formatter = Validation::DiagnosticFormatterPuppetStyle.new
      emitted_w = 0
      emitted_dw = 0
      acceptor.warnings.each do |w|
        if w.severity == :deprecation
          # Do *not* call Puppet.deprecation_warning it is for internal deprecation, not
          # deprecation of constructs in manifests! (It is not designed for that purpose even if
          # used throughout the code base).
          #
          log_message(:warning, formatter, w) if emitted_dw < max_deprecations
          emitted_dw += 1
        else
          log_message(:warning, formatter, w) if emitted_w < max_warnings
          emitted_w += 1
        end
        break if emitted_w >= max_warnings && emitted_dw >= max_deprecations # but only then
      end
    end

    # If there were errors, report the first found. Use a puppet style formatter.
    errors = acceptor.errors
    if errors.size > 0
      unless emit_errors
        raise emit_exception.new(emit_message)
      end
      formatter = Validation::DiagnosticFormatterPuppetStyle.new
      if errors.size == 1 || max_errors <= 1
        # raise immediately
        exception = create_exception(emit_exception, emit_message, formatter, errors[0])
        # if an exception was given as cause, use it's backtrace instead of the one indicating "here"
        if errors[0].exception
          exception.set_backtrace(errors[0].exception.backtrace)
        end
        raise exception
      end
      emitted = 0
      if emit_message
        Puppet.err(emit_message)
      end
      errors.each do |e|
        log_message(:err, formatter, e)
        emitted += 1
        break if emitted >= max_errors
      end
      giving_up_message = if (emit_warnings && warnings.size > 0)
                            _("Language validation logged %{error_count} errors, and %{warning_count} warnings. Giving up") %
                                { error_count: errors.size, warning_count: warnings.size }
                          else
                            _("Language validation logged %{error_count} errors. Giving up") %
                                { error_count: errors.size }
                          end
      exception = emit_exception.new(giving_up_message)
      exception.file = errors[0].file
      raise exception
    end
  end

  def self.format_with_prefix(prefix, message)
    return message unless prefix
    [prefix, message].join(' ')
  end

  def self.warning(semantic, issue, args)
    Puppet::Util::Log.create({
      :level => :warning,
      :message => issue.format(args),
      :arguments => args,
      :issue_code => issue.issue_code,
      :file => semantic.file,
      :line => semantic.line,
      :pos => semantic.pos,
    })
  end

  def self.error(exception_class, semantic, issue, args)
    raise exception_class.new(issue.format(args), semantic.file, semantic.line, semantic.pos, nil, issue.issue_code, args)
  end

  def self.create_exception(exception_class, emit_message, formatter, diagnostic)
    file = diagnostic.file
    file = (file.is_a?(String) && file.empty?) ? nil : file
    line = pos = nil
    if diagnostic.source_pos
      line = diagnostic.source_pos.line
      pos = diagnostic.source_pos.pos
    end
    exception_class.new(format_with_prefix(emit_message, formatter.format_message(diagnostic)), file, line, pos, nil, diagnostic.issue.issue_code, diagnostic.arguments)
  end
  private_class_method :create_exception

  def self.log_message(severity, formatter, diagnostic)
    file = diagnostic.file
    file = (file.is_a?(String) && file.empty?) ? nil : file
    line = pos = nil
    if diagnostic.source_pos
      line = diagnostic.source_pos.line
      pos = diagnostic.source_pos.pos
    end
    Puppet::Util::Log.create({
        :level => severity,
        :message => formatter.format_message(diagnostic),
        :arguments => diagnostic.arguments,
        :issue_code => diagnostic.issue.issue_code,
        :file => file,
        :line => line,
        :pos => pos,
      })
  end
  private_class_method :log_message
end
end