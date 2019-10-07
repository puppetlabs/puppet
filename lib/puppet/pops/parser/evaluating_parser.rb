module Puppet::Pops
module Parser

# Does not support "import" and parsing ruby files
#
class EvaluatingParser

  attr_reader :parser

  def initialize()
    @parser = Parser.new()
  end

  def self.singleton
    @instance ||= new
  end

  def parse_string(s, file_source = nil)
    @file_source = file_source
    clear()
    # Handling of syntax error can be much improved (in general), now it bails out of the parser
    # and does not have as rich information (when parsing a string), need to update it with the file source
    # (ideally, a syntax error should be entered as an issue, and not just thrown - but that is a general problem
    # and an improvement that can be made in the eparser (rather than here).
    # Also a possible improvement (if the YAML parser returns positions) is to provide correct output of position.
    #
    begin
      assert_and_report(parser.parse_string(s, file_source)).model
    rescue Puppet::ParseErrorWithIssue => e
      raise e
    rescue Puppet::ParseError => e
      # TODO: This is not quite right, why does not the exception have the correct file?
      e.file = @file_source unless e.file.is_a?(String) && !e.file.empty?
      raise e
    end
  end

  def parse_file(file)
    @file_source = file
    clear()
    assert_and_report(parser.parse_file(file)).model
  end

  def evaluate_string(scope, s, file_source = nil)
    evaluate(scope, parse_string(s, file_source))
  end

  def evaluate_file(scope, file)
    evaluate(scope, parse_file(file))
  end

  def clear()
    @acceptor = nil
  end

  # Create a closure that can be called in the given scope
  def closure(model, scope)
    Evaluator::Closure::Dynamic.new(evaluator, model, scope)
  end

  def evaluate(scope, model)
    return nil unless model
    evaluator.evaluate(model, scope)
  end

  # Evaluates the given expression in a local scope with the given variable bindings
  # set in this local scope, returns what the expression returns.
  #
  def evaluate_expression_with_bindings(scope, variable_bindings, expression)
    evaluator.evaluate_block_with_bindings(scope, variable_bindings, expression)
  end

  def evaluator
    # Do not use the cached evaluator if this is a migration run
    if (Puppet.lookup(:migration_checker) { nil })
      return Evaluator::EvaluatorImpl.new()
    end
    @@evaluator ||= Evaluator::EvaluatorImpl.new()
    @@evaluator
  end

  def convert_to_3x(object, scope)
    evaluator.convert(object, scope, nil)
  end

  def validate(parse_result)
    resulting_acceptor = acceptor()
    validator(resulting_acceptor).validate(parse_result)
    resulting_acceptor
  end

  def acceptor()
    Validation::Acceptor.new
  end

  def validator(acceptor)
    Validation::ValidatorFactory_4_0.new().validator(acceptor)
  end

  def assert_and_report(parse_result)
    return nil unless parse_result
    if parse_result['source_ref'].nil? || parse_result['source_ref'] == ''
      parse_result['source_ref'] = @file_source
    end
    validation_result = validate(parse_result.model)

    IssueReporter.assert_and_report(validation_result,
                                          :emit_warnings => true)
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
  # TODO: Handle \uXXXX characters ??
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

  class EvaluatingEppParser < EvaluatingParser
    def initialize()
      @parser = EppParser.new()
    end
  end
end
end
end
