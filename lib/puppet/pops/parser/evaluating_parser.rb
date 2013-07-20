
# Does not support "import" and parsing ruby files
#
class Puppet::Pops::Parser::EvaluatingParser

  def initialize()
    @parser = Puppet::Pops::Parser::Parser.new()
  end

  def parse_string(s, file_source = 'unknown')
    @file_source = file_source
    clear()
    assert_and_report(@parser.parse_string(s))
  end

  def parse_file(file)
    @file_source = file
    clear()
    assert_and_report(@parser.parse_file(file))
  end

  def evaluate_string(scope, s, file_source='unknown')
    evaluate(scope, parse_string(s, file_source))
  end

  def evaluate_file(file)
    evaluate(parse_file(file))
  end

  def clear()
    @acceptor = nil
  end

  def evaluate(scope, model)
    return nil unless model
    ast = Puppet::Pops::Model::AstTransformer.new(@file_source, nil).transform(model)
    return nil unless ast
    ast.safeevaluate(scope)
  end

  def acceptor()
    @acceptor ||= Puppet::Pops::Validation::Acceptor.new
    @acceptor
  end

  def validator()
    @validator ||= Puppet::Pops::Validation::ValidatorFactory_3_1.new().validator(acceptor)
  end

  def assert_and_report(parse_result)
    return nil unless parse_result
    validator.validate(parse_result)

    max_errors = Puppet[:max_errors]
    max_warnings = Puppet[:max_warnings] + 1
    max_deprecations = Puppet[:max_deprecations] + 1

    # If there are warnings output them
    warnings = acceptor.warnings
    if warnings.size > 0
      formatter = Puppet::Pops::Validation::DiagnosticFormatterPuppetStyle.new
      emitted_w = 0
      emitted_dw = 0
      acceptor.warnings.each {|w|
        if w.severity == :deprecation
          # Do *not* call Puppet.deprecation_warning it is for internal deprecation, not
          # deprecation of constructs in manifests! (It is not designed for that purpose even if
          # used throughout the code base).
          #
          Puppet.warning(formatter.format(w)) if emitted_dw < max_deprecations
          emitted_dw += 1
        else
          Puppet.warning(formatter.format(w)) if emitted_w < max_warnings
          emitted_w += 1
        end
        break if emitted_w > max_warnings && emitted_dw > max_deprecations # but only then
      }
    end

    # If there were errors, report the first found. Use a puppet style formatter.
    errors = acceptor.errors
    if errors.size > 0
      formatter = Puppet::Pops::Validation::DiagnosticFormatterPuppetStyle.new
      if errors.size == 1 || max_errors <= 1
        # raise immediately
        raise Puppet::ParseError.new(formatter.format(errors[0]))
      end
      emitted = 0
      errors.each do |e|
        Puppet.err(formatter.format(e))
        emitted += 1
        break if emitted >= max_errors
      end
      warnings_message = warnings.size > 0 ? ", and #{warnings.size} warnings" : ""
      giving_up_message = "Found #{errors.size} errors#{warnings_message}. Giving up"
      exception = Puppet::ParseError.new(giving_up_message)
      exception.file = errors[0].file
      raise exception
    end
    parse_result
  end

  def quote(x)
    self.class.quote(x)
  end

  # Translates an already parsed string that contains control characters, quotes
  # and backslashes into a quoted string where all such constructs have been escaped.
  # Parsing the return value of this method using the puppet parser should yield
  # exactly the same string as the argument passed to this method
  #
  # The method makes an exception for the two character sequences \$ and \s. They
  # will not be escaped since they have a special meaning in puppet syntax.
  #
  # @param x [String] The string to quote and "unparse"
  # @return [String] The quoted string
  #
  def self.quote(x)
    escaped = '"'
    p = nil
    x.each_char do |c|
      case p
      when nil
        # do nothing
      when "\t"
        escaped << '\\t'
      when "\n"
        escaped << '\\n'
      when "\f"
        escaped << '\\f'
      # TODO: \cx is a range of characters - skip for now
      #      when "\c"
      #        escaped << '\\c'
      when '"'
        escaped << '\\"'
      when '\\'
        escaped << if c == '$' || c == 's'; p; else '\\\\'; end # don't escape \ when followed by s or $
      else
        escaped << p
      end
      p = c
    end
    escaped << p unless p.nil?
    escaped << '"'
  end
end
